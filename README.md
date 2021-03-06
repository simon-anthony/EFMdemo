# EFM Demonstration Tools for AWS

Tools to support EFM Demo.

## Getting Started
### Prerequisites

#### Failover Manager
* EDB Failover Manager [EFM](https://www.enterprisedb.com/products/postgresql-automatic-failover-manager-cluster-high-availability) is required. Much of the configuration information obtained by the package tools relies on a working properties file being present for the cluster.

#### Linux Packages
The following packages are required by the tools:

* jq
* libnotify

They will be automatically installed if the repositories are available.
Otherwise download these packages and install them beforehand.

## Installing from Packages

To download the latest RPM packages and review release notes, see the [EFMdemo releases](https://github.com/simon-anthony/efmdemo/releases) page.

Install the package with the usual RPM based tools: `rpm`, `yum` or `dnf`.

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. 


## Installing from a Tar Bundle

Download the latest release.

Unzip the package:

<pre>
tar xzf efmdemo-<i>m</i>.<i>n</i>.tar.gz
</pre>

Run `configure`:

```
./configure 
```

If desired to specify an installation destination other than `/usr/local` do so
with the usual configure mechanism:

```
./configure --prefix=/opt/EFMtools --with-efm-home=/usr/edb/efm-3.10
```

Build the software:
* `make`

and then install it:
* `make install`

### Configuring

Ensure that the *bindir* path derived from the install *prefix* in the `configure`
step is available in the `PATH` environment variable. Using the previous example where the default of `/user/local/bin` is not chosen:

<pre>
PATH=$PATH:/opt/EFMtools/bin
</pre>

## Usage

Details to follow.

## Developing
To develop the package clone or download the repository.
GNU Autotools are required for development.

#### GNU Autotools
The [GNU Autotools](https://en.wikipedia.org/wiki/GNU_Autotools) are required
to build and deploy the source packages.

## Building RPMS from the Source Tree
Set `%_topdir` in the file `$HOME/.rpmmacros`

<pre><code>topdir=`eval echo \`sed -n '
    /^%_topdir/ {
        s;%_topdir[     ]*;;
        s;%{getenv:HOME};$HOME;
        p
    }' ~/.rpmmacros\``

echo topdir is $topdir
</code></pre>

Create the build directories:

<pre><code>for dir in BUILD BUILDROOT RPMS SOURCES SPECS SRPMS
do
    mkdir -p $topdir/$dir
done
</code></pre>

Bootstrap the **autoconf** tools:

* `autoreconf --install`

Then run configure:

* `./configure`

This will create the necsessary <code>Makefile</code> that is required to build the source tarball.
Then we can create the tarball:

* `make dist-gzip`

We can then move the package into the `SOURCES` directory:

* `mv efmdemo-`*vers*`.tar.gz $topdir/SOURCES`

And we also need a copy the spec file to the `SPECS` directory:

* `cp -f efmdemo.spec $topdir/SPECS`

Finally, build the package:

* `rpmbuild -bb $topdir/SPECS/efmbuild.spec`


## Authors

* **Simon Anthony** - *Initial work* - * [Simon Anthony](https://github.com/simon-anthony)

See also the list of [contributors](https://github.com/simon-anthony/efmtools/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

