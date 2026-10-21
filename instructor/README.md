# Instructor notes (solution branch only)

- `models/`: reference answer key for all four migrations. It reaches 4/4 parity.
  Use this branch as a fallback if a live migration runs long: `git checkout solution -- models/`.
- `instructor/generate_data.py`: regenerates `seeds/raw` and `seeds/legacy_targets`.
  The legacy outputs are computed in Python with ROUND_HALF_UP, which matches Snowflake ROUND on NUMBER.
  `python instructor/generate_data.py .`

Do **not** merge this branch into `main`. Wizard would read the answers.
