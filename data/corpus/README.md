# data/corpus

Drop cleared `.mid` files in here (subdirectories are fine), then:

```sh
python3 -m middaw.corpus ingest     # computes every derived label
python3 -m middaw.corpus validate   # tells you what is missing
```

`ingest` writes `manifest.json`. It fills in the **derived** labels only — it
never invents provenance or tags, so a new file arrives failing validation and
stays failing until a human clears its rights. That is deliberate.

See [../../docs/LABELLING.md](../../docs/LABELLING.md) for the schema and
[../../docs/DATASET.md](../../docs/DATASET.md) for where to source files.

`manifest.json` is the thing worth committing. Whether the `.mid` files
themselves belong in git depends on their licences and their size — some
licences require you to pass the licence along with the file.
