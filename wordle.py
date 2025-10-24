#!/usr/bin/env python3
"""
Wordle Solver - An interactive tool to help solve Wordle puzzles.

This solver uses letter frequency analysis and a trie data structure
to suggest optimal guesses and narrow down possible answers based on
the game's feedback.
"""

import argparse
import sys
from pathlib import Path
from typing import Dict, List, Set

# Constants
WORD_LENGTH = 5
CORRECT_POSITION = 'X'
WRONG_POSITION = 'x'
NOT_IN_WORD = '.'
UNIQUE_LETTER_BONUS = 10000
KNOWN_CHAR_BONUS = 10000
TRIE_END_MARKER = "done"


class WordleSolver:
    """
    A Wordle puzzle solver that suggests optimal guesses based on
    letter frequency analysis and eliminates possibilities based on feedback.
    """

    def __init__(self, answers_file: str = "answers.txt",
                 guesses_file: str = "guesses.txt",
                 debug: bool = False,
                 solve_mode: bool = False,
                 use_information_theory: bool = False,
                 search_all_words: bool = False):
        """
        Initialize the Wordle solver.

        Args:
            answers_file: Path to file containing possible answer words
            guesses_file: Path to file containing valid guess words
            debug: Enable debug output
            solve_mode: Show word suggestions and scores
            use_information_theory: Use information-theoretic scoring (slower but optimal)
            search_all_words: Consider all valid guesses, not just remaining answers
        """
        self.debug = debug
        self.solve_mode = solve_mode
        self.use_information_theory = use_information_theory
        self.search_all_words = search_all_words

        self.answers: List[str] = []
        self.all_words: List[str] = []
        self.trie: Dict = {}
        self.char_frequencies: Dict[str, int] = {}
        self.sorted_chars: List[str] = []
        self.candidate_words: Dict[str, float] = {}
        self.known_chars: Set[str] = set()

        self._load_word_lists(answers_file, guesses_file)
        self._initialize_characters()

    def _load_word_lists(self, answers_file: str, guesses_file: str) -> None:
        """Load answer and guess word lists from files."""
        try:
            answers_path = Path(answers_file)
            with answers_path.open('r') as f:
                for line in f:
                    word = line.rstrip('\r\n')
                    self.answers.append(word)
                    self.all_words.append(word)
        except IOError as e:
            print(f"Error: Can't open {answers_file}")
            sys.exit(1)

        try:
            guesses_path = Path(guesses_file)
            with guesses_path.open('r') as f:
                for line in f:
                    word = line.rstrip('\r\n')
                    self.all_words.append(word)
        except IOError as e:
            print(f"Error: Can't open {guesses_file}")
            sys.exit(1)

    def _initialize_characters(self) -> None:
        """Initialize valid characters (a-z) with default frequency."""
        self.char_frequencies = {chr(i): 1 for i in range(ord('a'), ord('z') + 1)}

    def build_trie(self) -> None:
        """Build a trie data structure from remaining possible answers."""
        self.trie = {}
        for word in self.answers:
            self._insert_word_to_trie(word)

    def _insert_word_to_trie(self, word: str) -> None:
        """
        Insert a word into the trie structure.

        Args:
            word: Word to insert
        """
        node = self.trie
        for letter in word:
            if letter not in node:
                node[letter] = {}
            node = node[letter]
        node[TRIE_END_MARKER] = True

    def calculate_char_frequencies(self) -> None:
        """Calculate character frequency across remaining possible answers."""
        char_counts = {char: 0 for char in self.char_frequencies}

        for word in self.answers:
            for char in self.char_frequencies:
                if char in word:
                    char_counts[char] += 1

        if self.debug:
            print("\nCharacter distribution:")

        self.sorted_chars = []
        for char in sorted(char_counts.keys(), key=lambda x: char_counts[x], reverse=True):
            if char_counts[char] > 0:
                self.sorted_chars.append(char)
                self.char_frequencies[char] = char_counts[char]
                if self.debug:
                    print(f"  {char}: {char_counts[char]}")
            else:
                # Remove characters that don't appear in any remaining words
                del self.char_frequencies[char]

    def find_candidate_words(self) -> None:
        """Find all valid words that can be formed from available letters."""
        self.candidate_words = {}

        if self.use_information_theory and self.search_all_words:
            # When using information theory with expanded search,
            # evaluate all valid guesses (not just remaining answers)
            if self.debug:
                print(f"\nEvaluating {len(self.all_words)} possible guesses...")

            for i, word in enumerate(self.all_words):
                self.candidate_words[word] = self._calculate_word_score(word)

                # Progress indicator for large searches
                if self.debug and (i + 1) % 500 == 0:
                    print(f"  Evaluated {i + 1}/{len(self.all_words)} words...")
        else:
            # Use trie-based search (original method)
            # Prioritize known characters
            search_order = list(self.known_chars) + self.sorted_chars
            self._search_trie(self.trie, "", search_order)

    def _search_trie(self, node: Dict, current_word: str, available_chars: List[str]) -> None:
        """
        Recursively search the trie to find valid words.

        Args:
            node: Current trie node
            current_word: Word built so far
            available_chars: Characters available for forming words
        """
        # Check if we've found a complete word
        if TRIE_END_MARKER in node:
            self.candidate_words[current_word] = self._calculate_word_score(current_word)

        # Try each available character
        for char in available_chars:
            if char in node:
                self._search_trie(node[char], current_word + char, available_chars)

    def _get_feedback_pattern(self, guess: str, answer: str) -> str:
        """
        Simulate the feedback pattern that Wordle would give for a guess against an answer.

        Args:
            guess: The guessed word
            answer: The actual answer word

        Returns:
            Feedback string (X=correct position, x=wrong position, .=not in word)
        """
        feedback = [''] * WORD_LENGTH
        answer_chars = list(answer)

        # First pass: mark correct positions (X)
        for i in range(WORD_LENGTH):
            if guess[i] == answer[i]:
                feedback[i] = CORRECT_POSITION
                answer_chars[i] = None  # Mark as used

        # Second pass: mark wrong positions (x) or not in word (.)
        for i in range(WORD_LENGTH):
            if feedback[i] == CORRECT_POSITION:
                continue  # Already marked

            if guess[i] in answer_chars:
                feedback[i] = WRONG_POSITION
                # Remove first occurrence of this character
                answer_chars[answer_chars.index(guess[i])] = None
            else:
                feedback[i] = NOT_IN_WORD

        return ''.join(feedback)

    def _calculate_expected_remaining(self, guess: str) -> float:
        """
        Calculate the expected number of remaining answers after making this guess.
        Uses information theory: groups answers by feedback pattern and calculates
        expected value. Lower is better (more information gained).

        Args:
            guess: The word to evaluate

        Returns:
            Expected number of remaining answers (lower = better guess)
        """
        pattern_counts: Dict[str, int] = {}

        # Group remaining answers by their feedback pattern
        for answer in self.answers:
            pattern = self._get_feedback_pattern(guess, answer)
            pattern_counts[pattern] = pattern_counts.get(pattern, 0) + 1

        # Calculate expected value: E[remaining] = sum(count^2) / total
        # This represents the average number of words left after getting feedback
        total = len(self.answers)
        if total == 0:
            return 0.0

        expected = sum(count * count for count in pattern_counts.values()) / total

        return expected

    def _calculate_word_score(self, word: str) -> float:
        """
        Calculate a score for a word based on either character frequency or information theory.

        Args:
            word: Word to score

        Returns:
            Score value (higher is better)
        """
        if self.use_information_theory:
            # Information-theoretic scoring: lower expected remaining = better
            # We negate it so higher scores are better (for consistent sorting)
            expected_remaining = self._calculate_expected_remaining(word)
            # Return negative so lower expected remaining gives higher score
            # Also subtract a small bonus if word is in remaining answers (tie-breaker)
            bonus = 0.001 if word in self.answers else 0
            return -expected_remaining + bonus
        else:
            # Frequency-based scoring (original method)
            score = 0

            for letter in word:
                # Use .get() to handle letters that have been removed from char_frequencies
                score += self.char_frequencies.get(letter, 0)
                if letter in self.known_chars:
                    score += KNOWN_CHAR_BONUS

            # Bonus for words with all unique letters
            if len(set(word)) == WORD_LENGTH:
                score += UNIQUE_LETTER_BONUS

            return float(score)

    def prune_answers(self, guess: str, feedback: str) -> None:
        """
        Remove words that don't match the feedback from the guess.

        Args:
            guess: The word that was guessed
            feedback: Feedback string (X=correct position, x=wrong position, .=not in word)
        """
        # First pass: identify known characters and remove them from search space
        for position in range(WORD_LENGTH):
            feedback_char = feedback[position]
            guessed_char = guess[position]

            if feedback_char in (CORRECT_POSITION, WRONG_POSITION):
                self.known_chars.add(guessed_char)

            # Remove character from search space (we now know something about it)
            if guessed_char in self.char_frequencies:
                del self.char_frequencies[guessed_char]

        # Second pass: filter words based on constraints
        filtered_answers = []
        for word in self.answers:
            if self.debug:
                print(f"Evaluating: {word}")

            if self._word_matches_feedback(word, guess, feedback):
                filtered_answers.append(word)

        self.answers = filtered_answers

    def _word_matches_feedback(self, word: str, guess: str, feedback: str) -> bool:
        """
        Check if a word matches the constraints from the guess feedback.

        Args:
            word: Candidate word to check
            guess: The guessed word
            feedback: Feedback string

        Returns:
            True if word matches all constraints, False otherwise
        """
        for position in range(WORD_LENGTH):
            feedback_char = feedback[position]
            guessed_char = guess[position]

            if self.debug:
                print(f"  Checking position {position}: '{guessed_char}' -> {feedback_char}")

            # Character not in word (and wasn't previously found)
            if (feedback_char == NOT_IN_WORD and
                guessed_char in word and
                guessed_char not in self.known_chars):
                return False

            # Character in word but not at this position - word must contain it
            if feedback_char == WRONG_POSITION and guessed_char not in word:
                return False

            # Character in word but at wrong position - can't be at same position in candidate
            if feedback_char == WRONG_POSITION and word[position] == guessed_char:
                return False

            # Duplicate letter case: marked as not in word but we know it exists elsewhere
            if (feedback_char == NOT_IN_WORD and
                word[position] == guessed_char and
                guessed_char in self.known_chars):
                return False

            # Character must be at correct position
            if feedback_char == CORRECT_POSITION and word[position] != guessed_char:
                return False

        return True

    def get_user_guess(self) -> str:
        """
        Prompt user for their guess and validate it.

        Returns:
            Valid guess word
        """
        while True:
            guess = input("\nWhich word did you try?\n").strip().lower()

            if guess in self.all_words:
                return guess
            else:
                print("Not a valid word, try again!")

    def get_user_feedback(self) -> str:
        """
        Prompt user for feedback and validate it.

        Returns:
            Valid feedback string
        """
        while True:
            feedback = input(f"\nWhat is the result ({CORRECT_POSITION} for right place, "
                           f"{WRONG_POSITION} for right letter, {NOT_IN_WORD} for incorrect)?\n").strip()

            if (len(feedback) == WORD_LENGTH and
                all(c in f'{CORRECT_POSITION}{WRONG_POSITION}{NOT_IN_WORD}' for c in feedback)):
                return feedback
            else:
                print("Not a valid result, try again!")

    def display_suggestions(self) -> None:
        """Display suggested words and remaining answer count."""
        if self.solve_mode:
            print("\nTry one of these words:")
            # Sort by score (higher is better), show top suggestions
            sorted_words = sorted(self.candidate_words.keys(),
                                key=lambda x: self.candidate_words[x],
                                reverse=True)

            # Limit display to top 20 words for readability
            display_count = min(20, len(sorted_words))
            for word in sorted_words[:display_count]:
                score = self.candidate_words[word]
                if self.use_information_theory:
                    # For info theory, show expected remaining words
                    expected = -score  # We negated it earlier
                    marker = "*" if word in self.answers else " "
                    print(f"  {word}{marker}: {expected:.2f} expected remaining")
                else:
                    print(f"  {word}: {score:.0f}")

            if len(sorted_words) > display_count:
                print(f"  ... and {len(sorted_words) - display_count} more")

        count = len(self.answers)  # Show actual remaining answers, not candidates
        if not self.solve_mode:
            print(f"\n{count} answer{'s' if count != 1 else ''} remaining")

    def solve(self) -> None:
        """Main game loop for solving Wordle puzzles."""
        while True:
            # Build trie from remaining answers
            self.build_trie()

            # Calculate letter frequencies
            self.calculate_char_frequencies()

            # Find candidate words using frequency analysis
            self.find_candidate_words()

            # Display suggestions
            self.display_suggestions()

            # Check if we're down to one answer
            if len(self.answers) == 1:
                if self.solve_mode:
                    print(f"\nAnswer is: {self.answers[0]}")
                else:
                    print("\nOnly 1 answer remaining!")
                break

            # Get user input
            guess = self.get_user_guess()
            feedback = self.get_user_feedback()

            # Prune possibilities based on feedback
            self.prune_answers(guess, feedback)


def main() -> None:
    """Parse arguments and run the Wordle solver."""
    parser = argparse.ArgumentParser(
        description='Interactive Wordle puzzle solver',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Example usage:
  %(prog)s              # Basic mode (shows answer count only)
  %(prog)s -s           # Solve mode (shows word suggestions)
  %(prog)s -d           # Debug mode (shows detailed analysis)
  %(prog)s -i -s        # Use information-theoretic scoring (optimal but slower)
  %(prog)s -i -a -s     # Use info theory + search all valid guesses (most optimal)
        """
    )
    parser.add_argument('-d', '--debug', action='store_true',
                       help='enable debug output')
    parser.add_argument('-s', '--solve', action='store_true',
                       help='enable solve mode (show word suggestions)')
    parser.add_argument('-i', '--info-theory', action='store_true',
                       help='use information-theoretic scoring (slower but optimal)')
    parser.add_argument('-a', '--all-words', action='store_true',
                       help='consider all valid guesses, not just remaining answers (use with -i)')
    args = parser.parse_args()

    # Debug mode implies solve mode
    # Info theory mode implies solve mode
    solve_mode = args.solve or args.debug or args.info_theory

    # Create and run solver
    solver = WordleSolver(
        debug=args.debug,
        solve_mode=solve_mode,
        use_information_theory=args.info_theory,
        search_all_words=args.all_words
    )
    solver.solve()


if __name__ == "__main__":
    main()
