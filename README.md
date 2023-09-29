# RubyGitUtil

# repo-gap-enumerater.rb

See [background explanation](Downstream_development.pdf)

Enumerate the gapped commits as .patch between the sourceRepoDir and the targetRepoDir

```
ruby repo-gap-enumerater.rb --help
Usage: -s sourceRepoDir -t targetRepoDir
    -s, --source=                    Specify source repo dir.
        --sourceGitOpt=
                                     Specify gitOpt for source repo dir.
    -t, --target=                    Specify target repo dir.
    -g, --gitPath=                   Specify target git path (regexp) if you want to limit to execute the git only
    -o, --output=                    Specify patch output path
        --manifestFile=
                                     Specify manifest file (default:manifest.xml)
    -j, --numOfThreads=              Specify number of threads (default:8)
    -v, --verbose                    Enable verbose status output (default:false)
```

Note that the .patch is generated as ```git format-patch```
Then you can apply ```git am```


```
$ ruby repo-gap-enumerater.rb -s ~/work/projectA -t ~/work/projectB -o ~/work/gap -sourceGitOpt="--author=yourCompany.com"
```

Then you can enumerate the missing commits from the ```-s``` specified project as ```-t``` specified project
