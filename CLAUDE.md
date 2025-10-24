# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Wordle solver that helps users solve Wordle puzzles interactively through the command line. The solver uses letter frequency analysis and a trie data structure to suggest optimal guesses.

The project has two implementations:
- **wordle.pl** - Original Perl implementation
- **wordle.py** - Python 3 port with identical functionality

## Running the Solvers

Both implementations have the same command-line interface:

```bash
# Python version (recommended)
python wordle.py              # Basic mode (shows answer count only)
python wordle.py -s           # Solve mode (shows word suggestions with scores)
python wordle.py -d           # Debug mode (shows detailed analysis)

# Perl version
./wordle.pl                   # Basic mode
./wordle.pl -s                # Solve mode
./wordle.pl -d                # Debug mode
```

Both programs are interactive:
1. They display candidate words (in solve mode) or remaining answer count
2. Prompt user: "Which word did you try?"
3. Prompt user: "What is the result (X for right place, x for right letter, . for incorrect)?"
4. Repeat until narrowed to one answer

## Data Files

- **answers.txt** - List of valid Wordle answer words (2,316 five-letter words)
- **guesses.txt** - Additional valid guess words not in the answer list

Both files are required and must be in the same directory as the solver scripts.

## Algorithm Architecture

Both implementations use the same algorithm:

1. **Trie Construction**: Build a trie (prefix tree) from remaining possible answers
2. **Frequency Analysis**: Calculate how often each letter appears across remaining answers
3. **Word Scoring**: Score candidate words based on:
   - Character frequency (higher = more common letters)
   - Known characters bonus (+10,000 per known letter)
   - Unique letters bonus (+10,000 if all 5 letters are unique)
4. **Pruning**: Filter answers based on user's guess feedback:
   - Remove words without correct-position letters (X)
   - Remove words without wrong-position letters (x)
   - Remove words with letters marked as not in word (.)
   - Handle duplicate letter edge cases

### Key Implementation Detail

**Critical bug pattern to avoid**: In wordle.py, when scoring words after pruning, letters may have been removed from `char_frequencies` dictionary. Always use `.get(letter, 0)` instead of direct dictionary access to avoid KeyError. This is already fixed in the current version.

## Code Structure

### Python (wordle.py)
- `WordleSolver` class encapsulates all solver logic
- Key methods:
  - `build_trie()` - Constructs trie from remaining answers
  - `calculate_char_frequencies()` - Computes letter frequency
  - `find_candidate_words()` - Searches trie for valid words
  - `prune_answers()` - Filters based on feedback
  - `_calculate_word_score()` - Scores words by frequency and uniqueness

### Perl (wordle.pl)
- Procedural implementation with global state
- Key subroutines mirror Python class methods
- Uses hash-of-hashes for trie structure

## Converting Between Implementations

When porting features between Perl and Python versions:
- Perl hash-of-hashes → Python nested dictionaries
- Perl arrays → Python lists
- The trie uses `"done"` as end-of-word marker in both implementations
- Both use same scoring algorithm with identical bonus values
