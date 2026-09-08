# https://perlmaven.com/file-modify-date
use strict;
use warnings;
use 5.010;
use Carp;
use CPAN::DistnameInfo;
use DateTime;
use Data::Dump qw(dd pp);
use File::Temp qw(tempfile tempdir);
use File::Spec;
use File::Copy::Recursive::Reduced qw(fcopy dircopy);
use Cwd;

# /tmp/List-RewriteElements-0.01.tar.gz

=pod

https://thenceforward.net/perl/modules/List-RewriteElements/archives/List-RewriteElements-0.01.tar.gz
...
http://backpan.cpantesters.org/authors/id/J/JK/JKEENAN/List-RewriteElements-0.04.tar.gz

=cut

my $distro = shift or croak "Need to specify My-Distro to be processed";

# Create the directory to hold the local checkout -- if that directory doesn't
# already exist.

my $checkout_dir = File::Spec->catdir($ENV{HOMEDIR}, 'gitwork', 'noncore', $distro);
unless (-d $checkout_dir) {
    mkdir $checkout_dir or croak "Unable to mkdir $checkout_dir";
    system(qq|git init $checkout_dir|) and croak "Unable to init repository in $checkout_dir";
}

my $workdir = "/home/jkeenan/learn/perl/$distro/";
chdir $workdir or croak "Unable to change to $workdir";
my $list = 'tarball-list.txt';
croak "Unable to locate $list in $workdir" unless -f $list;

my @tarballs = ();
open my $IN, '<', $list or croak "Unable to open $list for reading";
while (my $tb = <$IN>) {
    chomp $tb;
    next if $tb =~ m/^\s*$/;
    next if $tb =~ m/^#/;
    push @tarballs, $tb;
}
close $IN or croak "Unable to close $list after reading";
dd \@tarballs;

my @tarball_data;

# Before downloading, analyze the URL of each tarball we intend to process

for my $url (@tarballs) {
    my $url_data = analyze_url($url);
    push @tarball_data, $url_data;
}
#dd \@tarball_data;

# Now we have to download each tarball (where to?), get its last modification time, format
# that time into YYYYMMDD, store that in @tarball_data for later use in commit message and tags
# Then we'll have to unpack the tarball, cd into it, tarover it to the
# repository, examine the git diff, etc.

my $startdir = cwd();
my $tdir = File::Spec->catdir('', 'tmp', $distro);
mkdir $tdir or croak "Unable to mkdir" unless (-d $tdir);
chdir $tdir or croak "Unable to chdir";
for my $d (@tarball_data) {
    system(qq|wget $d->{url}|) and croak "Unable to wget from $d->{url}";
    # We now have the tarball on disk.
    # Before unpacking tarball, we should get mtime, format it for YYYYMMDD, add to
    # $tarball_data:
    $d->{last_upload} = get_upload_date($d->{filename});
    my $message = "$d->{distvname} uploaded $d->{last_upload}";
    say STDERR "MMM: $message";
    system(qq|tar xzf $d->{filename}|) and croak "Unable to unpack $d->{filename}";

    my $FROM = File::Spec->catdir(cwd(), $d->{distvname});
    say STDERR "CURR: ", cwd();
    say STDERR "FROM: $FROM";
    say STDERR "TO:   $checkout_dir";
    croak "Could not locate $FROM" unless -d $FROM;
    croak "Could not locate $checkout_dir" unless -d $checkout_dir;

    dircopy($FROM, $checkout_dir)
        or croak "Unable to copy $FROM to checkout_dir $checkout_dir";

    chdir $checkout_dir or croak "Unable to chdir to $checkout_dir";
    system(qq|git add .|) and croak "Unable to git add";
    system(qq|git commit -m "$message"|) and croak "Unable to git commit";
    system(qq|git tag "$d->{version}"|) and croak "Unable to git tag";
    chdir $tdir or croak "Could not change back to $tdir";
}
chdir $startdir or croak "Could not change back to $startdir";


########## SUBROUTINES ##########

sub get_upload_date {
    my $filename = shift;
    my $modify_time = (stat($filename))[9];
    my @lt = localtime((stat($filename))[9]);
    my $YYYYMMDD = sprintf("%04d%02d%02d" => (
        ($lt[5] + 1900),
        ($lt[4] + 1),
        ($lt[3]),
    ));
    return $YYYYMMDD;
}

sub analyze_url {
    my $url = shift or croak "Lack argument to analyze_url()";
    my %url_data;
    my ($source, $urlbase, $pathname, $filename, $distvname, $dist, $version);
    if ($url =~ m{^https://thenceforward.net/perl/modules/$distro/archives/(.*)$}) {
        $urlbase = $1;
        $url_data{url} = $url;
        $url_data{source} = 'thencef';
        $pathname = "authors/id/J/JK/JKEENAN/$urlbase";
        my $d = CPAN::DistnameInfo->new($pathname);
        $url_data{filename} = $d->filename;
        $url_data{distvname} = $d->distvname;
        $url_data{dist} = $d->dist;
        $url_data{version} = $d->version;
    }
    elsif ($url =~ m{^http://backpan.cpantesters.org/(authors/id/J/JK/JKEENAN/.*)$}) {
        $pathname = $1;
        $url_data{url} = $url;
        $url_data{source} = 'backpan';
        my $d = CPAN::DistnameInfo->new($pathname);
        $url_data{filename} = $d->filename;
        $url_data{distvname} = $d->distvname;
        $url_data{dist} = $d->dist;
        $url_data{version} = $d->version;
    }
    else {
        croak "URL $url not parsed";
    }

    return { %url_data };
}


__END__
my $filename = shift or die "Usage: $0 FILENAME\n";


# Once downloaded:

my @stat = stat($filename);
dd \@stat;
say $stat[9];
my $modify_time = (stat($filename))[9];
say $modify_time;
say scalar localtime($modify_time);

my @lt = localtime($modify_time);
dd \@lt;
my $YYYY = sprintf("%04d" => ($lt[5] + 1900));
my $MM =   sprintf("%02d" => ($lt[4] + 1));
my $DD =   sprintf("%02d" => ($lt[3]));
say join '-' => ($YYYY, $MM, $DD);
my $YYYYMMDD = sprintf("%04d%02d%02d" => (
    ($lt[5] + 1900),
    ($lt[4] + 1),
    ($lt[3]),
));
say $YYYYMMDD;

__END__


my $dt = DateTime->from_epoch( epoch => $modify_time );
say $dt;


my $modify_days = -M $filename;
say $modify_days;

say $^T - $modify_days * 60*60*24;

