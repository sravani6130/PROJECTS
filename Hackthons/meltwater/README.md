# Hangman competition solution

`hangman_submission.py` is a self-contained Kaggle submission implementation.
It learns from the competition `train.txt`, simulates each Hangman game against
the public `test.txt`, and writes the required `submission.csv`.

To submit it as a notebook, create a Kaggle Python notebook and paste the file
contents into a code cell. It automatically finds the usual competition input
mount, or any nested `train.txt`/`test.txt` files below `/kaggle/input`.
