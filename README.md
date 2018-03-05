# README for jkeenan/scripts-misc

This repository contains publicly accessible programs I have written and which
are available under the terms (MIT license) described in the `LICENSE` file.

These are executable programs written either in Perl 5 or Bourne-compatible
shell for the following purposes:

- Ongoing maintenance and development of the Perl 5 core distribution.
- Presentations to open-source conferences and user group meetings.

You should treat these programs as **alpha** code and use accordingly.  I make
no claim that they are as polished or efficient as, for example, the libraries
I have released to [CPAN](http://search.cpan.org/~/jkeenan/)

# PROGRAMS

## Perl 5 Core Distribution Aids

### `get_cpanm`

- Purpose

    Installs CPAN-library installer `cpanm` against a newly installed `perl`.

- Prerequisites

    `wget(1)`.

- Usage

    This program is installed automatically via `install_branch_for_testing` in
    this repository.  Once that program is run, change to the top-level of the
    newly installed `perl`.

        $> cd ~/testing/my_branch
        $> ./bin/cpanm List::Compare Text::CSV::Hashify <Other::CPAN::Module>

- Provenance

    [http://search.cpan.org/~miyagawa/Menlo-1.9005/script/cpanm-menlo](http://search.cpan.org/~miyagawa/Menlo-1.9005/script/cpanm-menlo) and 
    adapted from Florian Ragwitz and Karl Williamson.

### `get-test-smoke`

- Purpose

    Alternative `Test-Smoke` configuration; get quickly set up to smoke-test the
    Perl 5 core distribution.

- Prerequisites
    - CPAN libraries not found in Perl 5 core distribution

            $> cpan Perl::Download::FTP::Distribution \
                CGI::Util JSON JSON::XS System::Info \
                HTTP::Daemon HTTP::Message Test::NoWarnings

    - Environmental Variables

        The program presumes that your home directory can be located in an
        environmental variable known as `$HOMEDIR`.  If that is not the case, then
        call:

            $> export HOMEDIR=/home/<username>
- Usage

        $> export APPLICATION_DIR=/home/<username>/p5smoke
        $> ./get-test-smoke --application_dir=$APPLICATION_DIR
        $> cd $APPLICATION_DIR
        $> sh ./smokecurrent.sh

    For more information:  `perldoc get-test-smoke`.

- Provenance

    [Test-Smoke](http://search.cpan.org/dist/Test-Smoke/).

### `install_blead_for_testing`

Exactly equivalent to:

    $> install_branch_for_testing blead

See discussion of that program below.

### `install_branch_for_testing`

- Purpose

    Installs a branch of the Perl 5 core distribution for testing purposes,
    then installs `cpanm` against the newly installed `perl`.  Useful in
    assessing whether code in a branch might have a negative impact on CPAN
    libraries.

- Prerequisites
    - Directories

        Prior existence of two directories whose names are assigned to environmental
        variables:

        - &lt;$TESTINGDIR>

            A directory underneath which you will have directories such as `blead`,
            `threaded_blead`, etc., each representing a particular build of `perl`
            Under each of the latter you will have `bin` and `lib`.  Example:

                $> mkdir /home/<username>/testing/
                $> export TESTINGDIR=/home/<username>/testing  # place in .bashrc or .shrc

        - &lt;$SECONDARY\_CHECKOUT\_DIR>

            A `git` checkout of the Perl 5 core distribution.  This is labelled
            _"secondary"_ in the belief that you will not want to risk harm to the `git`
            checkout you use for everyday Perl 5 core development.  Example:

                $> cd /home/<username>/gitwork
                $> git clone git://perl5.git.perl.org/perl.git perl2
                $> export SECONDARY_CHECKOUT_DIR=/home/<username>/gitwork/perl2

    - Other environmental variables
        - `$TEST_JOBS`

            An integer such as 4 or 8, appropriate to the number of cores in your machine,
            which will determine how many jobs `make` will attempt to run in parallel.
    - Other items in PATH

        `git`; `make`; `get_cpanm` (in this repository)
- Usage

        $> install_branch_for_testing <branch>

    If no value is provided for `branch`>, program will default to installing
    `blead`.

- Provenance

    Adapted from Florian Ragwitz and Karl Williamson.

## Conference Presentation Aids

### `multipandoc`

- Purpose

    Convert POD into `.pdf`, `.html`, `.txt` and `.odt` files simultaneously.

- Prerequisites
    - `pandoc(1)`

        A general markup converter documented at [http://pandoc.org](http://pandoc.org).  Install with
        your operating system's ports installer.

    - `Pod::Pandoc(3)`

        CPAN distribution [Pod-Pandoc](http://search.cpan.org/dist/Pod-Pandoc/), which
        provides utility `pod2pandoc(1)`.
- Usage

        multipandoc \
          --sourcedir=/home/<username>/p5-codebase-health \
          --podfile=p5-codebase-health.pod \
          --outputdir=/home/<username>/tmp \
          --stub=p5-codebase-health \
          --verbose

    For more information:  `perldoc multipandoc`.
