# calabash3
calabash3 (3.0.52-SNAPSHOT) for use in future transpect projects.

We still need to optimize calabash.sh for use with/without config file. If you don’t want to use a config file, you can invoke it like this:

```
CFG=none calabash/calabash.sh --explain -i:source=… -o:result=… pipeline.xpl option1=val1 …
```

If you have a licensed Saxon 12, you can put its directory, named saxon and containing saxon-license.lic, next to the clone of this repo (in the same parent directory).

Then 

```
CFG=none calabash/calabash.sh --licensed:true info version
```

will return something like this:

```
XML Calabash version 3.0.52-SNAPSHOT (build b2b18a2b.1a8.03HHMM, 03 August 2026)
Running with Saxon PE version 12.7 using at most 1 of 16 available threads
Including EXProc contributed pipelines from 28 Dec 2025 at 11:19.
The default character set is UTF-8
```
