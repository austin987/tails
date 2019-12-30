#!perl

use strictures 2;

use lib qw{lib t/lib};

use Carp;
use Carp::Assert;
use Carp::Assert::More;
use Cwd;
use Data::Dumper;
use English qw{-no_match_vars};
use Fcntl ':mode';
use Function::Parameters;
use Test::More;
use Test::BDD::Cucumber::StepFile;

use Path::Tiny;
use Test::SslCertificates qw{generate_ssl_privkey generate_self_signed_ssl_cert populate_ssl_template};
use Test::Util;
use Test::WebServer::RedirectToHTTPS;
use Test::WebServer::Static;
use Test::WebServer::Static::SSL;
use Types::Path::Tiny qw{AbsPath};

my $bindir = path(__FILE__)->parent->parent->parent->parent->child('bin')->absolute;

$ENV{HARNESS_ACTIVE} = 1;

Given qr{^a usable temporary directory$}, fun ($c) {
    my $tempdir = $c->{stash}->{scenario}->{tempdir} = Path::Tiny->tempdir(cleanup => 0);
    ok(-d $tempdir);
    my $destdir = $c->{stash}->{scenario}->{destdir} = path($tempdir, 'destdir');
    $destdir->mkpath;
    ok($destdir->is_dir);
};

Given qr{^(a|another) random port$}, fun ($c) {
    my $port = 40000 + int(rand(10000));
    my $key  = $c->matches->[0] eq 'a' ? 'port' : 'another_port';
    $c->{stash}->{scenario}->{server}->{$key} = $port;
    ok(defined $c->{stash}->{scenario}->{server}->{$key});
};

fun prepare_webroot (AbsPath $webroot, $filename, $present, $webdir, $spec_type, $spec_value) {
    my ($size, $content);
    if (defined $spec_type) {
        if ($spec_type eq 'content') {
            $content = $spec_value;
        }
        elsif ($spec_type eq 'size') {
            $size = $spec_value;
        }
    }

    $webroot->mkpath;
    ok(-d $webroot->stringify);

    if ($present) {
        my $file = path($webroot, $webdir, $filename);
        $file->parent->mkpath;
        assert($file->parent->is_dir);
        assert(defined $content || defined $size);
        if (defined $content) {
            $file->spew($content);
        }
        else {
            $file->spew("c" x $size);
        }
        ok(-e $file->stringify);
        if (defined $content) {
            is($file->slurp, $content);
        }
        else {
            is(-s $file, $size);
        }
    }
}

Given qr{^a HTTP server that(| does not) serve[s]? "([^"]+)" in "([^"]+)"(?: with (content|size) "?([^"]*)"?)?}, fun ($c) {
    my $present    = $c->matches->[0] ? 0 : 1;
    my $filename   = $c->matches->[1];
    my $webdir     = $c->matches->[2];
    my $spec_type  = $c->matches->[3];
    my $spec_value = $c->matches->[4];

    my $webroot = path($c->{stash}->{scenario}->{tempdir}, 'webroot');
    prepare_webroot($webroot, $filename, $present, $webdir, $spec_type, $spec_value);

    my $port  = $c->{stash}->{scenario}->{server}->{port};
    my $s     = Test::WebServer::Static->new({webroot => $webroot}, $port);
    is($s->port(), $port, "Constructor set port correctly");
    my $pid   = $c->{stash}->{scenario}->{server}->{http_pid}  = $s->background();
    like($pid, '/^-?\d+$/', 'PID is numeric');
};

Given qr{^a HTTP server that redirects to ([^ ]+) over HTTPS$}, fun ($c) {
    my $target_hostname = $c->matches->[0];

    my $port  = $c->{stash}->{scenario}->{server}->{port};

    my $target = sprintf(
        "%s:%s",
        $target_hostname,
        $c->{stash}->{scenario}->{server}->{another_port}
    );

    my $s = Test::WebServer::RedirectToHTTPS->new({ target => $target }, $port);
    is($s->port(), $port, "Constructor set port correctly");
    my $pid   = $c->{stash}->{scenario}->{server}->{http_pid}  = $s->background();
    like($pid, '/^-?\d+$/', 'PID is numeric');
};

Given qr{^a HTTPS server (?:|on ([^ ]+)) that(| does not) serve[s]? "([^"]+)" in "([^"]+)"(?: with (content|size) "?([^"]*)"?)?}, fun ($c) {
    my $listen     = $c->matches->[0];
    my $present    = $c->matches->[1] ? 0 : 1;
    my $filename   = $c->matches->[2];
    my $webdir     = $c->matches->[3];
    my $spec_type  = $c->matches->[4];
    my $spec_value = $c->matches->[5];
    $listen //= '127.0.0.1';

    my $webroot = path($c->{stash}->{scenario}->{tempdir}, 'webroot');
    prepare_webroot($webroot, $filename, $present, $webdir, $spec_type, $spec_value);

    # We don't rely on SSL certificates for target files security,
    # so for more robustness, we need to ensure they don't get
    # in the way for dumb reasons; basically, we want to skip validation
    # in most cases => we try to test the worst case, that is a self-signed
    # certificate, whose hostname does not match the server's one.
    # It would be even better if it was expired, but apparently certtool
    # does not know how to do it, and mocking the system time for OpenSSL
    # does not look that easy.

    my $key      = path($c->{stash}->{scenario}->{tempdir}, "ssl_privkey") ->stringify;
    my $cert     = path($c->{stash}->{scenario}->{tempdir}, "ssl_cert")    ->stringify;
    my $template = path($c->{stash}->{scenario}->{tempdir}, "ssl_template")->stringify;

    populate_ssl_template({ outfile => $template });
    generate_ssl_privkey({ outfile => $key });
    generate_self_signed_ssl_cert({
        outfile => $cert, privkey => $key, template => $template,
    });

    my $port  = $c->{stash}->{scenario}->{server}->{another_port};
    my $s     = Test::WebServer::Static::SSL->new(
        { webroot => $webroot, cert => $cert, key => $key, },
        $port
    );
    is($s->port(), $port, "Constructor set port correctly");
    $s->host($listen);
    is($s->host(), $listen, "Constructor set host correctly");
    my $pid   = $c->{stash}->{scenario}->{server}->{https_pid}  = $s->background();
    like($pid, '/^-?\d+$/', 'PID is numeric');
};

When qr{^I download "([^"]+)" \(of expected size (\d+)\) from "([^"]+)", and check its hash is "([^"]+)"$}, fun ($c) {
    my $filename      = $c->matches->[0];
    my $expected_size = $c->matches->[1];
    my $webdir        = $c->matches->[2];
    my $expected_hash = $c->matches->[3];

    my $uri = sprintf("%s:%d/%s/%s",
                      "127.0.0.1",
                      $c->{stash}->{scenario}->{server}->{port},
                      $webdir,
                      $filename);
    $uri =~ s{//}{/}gxms;
    $uri = "http://$uri";

    my $output_filename
        = $c->{stash}->{scenario}->{output_filename}
        = path($c->{stash}->{scenario}->{destdir}, 'output.file');

    my $cmdline =
        path($bindir, "tails-iuk-get-target-file") .
        ' --uri "'         . $uri             . '"' .
        ' --hash_type "'   . 'sha256'         . '"' .
        ' --hash_value "'  . $expected_hash   . '"' .
        ' --output_file "' . $output_filename . '"' .
        ' --size "'        . $expected_size   . '"'
    ;
    $c->{stash}->{scenario}->{output} = `umask 077 && $cmdline 2>&1`;
    $c->{stash}->{scenario}->{exit_code} = ${^CHILD_ERROR_NATIVE};
};

Then qr{^it should succeed$}, fun ($c) {
    Test::Util::kill_httpd($c);

    ok(defined $c->{stash}->{scenario}->{exit_code})
        and
    is($c->{stash}->{scenario}->{exit_code}, 0);

    if (defined $c->{stash}->{scenario}->{exit_code}
            && $c->{stash}->{scenario}->{exit_code} != 0
            && exists $c->{stash}->{scenario}->{output}
            && defined $c->{stash}->{scenario}->{output}) {
        warn $c->{stash}->{scenario}->{output};
    }
};

Then qr{^it should fail$}, fun ($c) {
    Test::Util::kill_httpd($c);

    ok(defined $c->{stash}->{scenario}->{exit_code})
        and
    isnt($c->{stash}->{scenario}->{exit_code}, 0);
};

Then qr{^I should be told "([^"]+)"$}, fun ($c) {
    my $expected_err = $c->matches->[0];
    like($c->{stash}->{scenario}->{output}, qr{$expected_err});
};

Then qr{^I should(| not) see the downloaded file in the temporary directory$}, fun ($c) {
    my $wanted   = $c->matches->[0] ? 0 : 1;

    my $output_filename = $c->{stash}->{scenario}->{output_filename};
    $wanted ? ok(-e $output_filename) : ok(! -e $output_filename);
};

Then qr{^the SHA-256 of the downloaded file should be "([^"]+)"$}, fun ($c) {
    my $expected_hash = $c->matches->[0];

    my $output_filename = $c->{stash}->{scenario}->{output_filename};
    assert(-e $output_filename);

    my $hash_line = `sha256sum "$output_filename"`;
    assert_is(${^CHILD_ERROR_NATIVE}, 0);

    my @hash_words = split(/\s+/, $hash_line);
    is($expected_hash, $hash_words[0]);
};

Then qr{^the downloaded file should be world-readable$}, fun ($c) {
    my $output_filename = $c->{stash}->{scenario}->{output_filename};
    assert(-e $output_filename);

    my $mode       = (stat($output_filename))[2];
    my $other_read = $mode & S_IROTH;
    ok($other_read);
};

After fun ($c) {
    if (defined $c->{stash}->{scenario}->{server}->{http_pid}) {
        kill $c->{stash}->{scenario}->{server}->{http_pid};
    }
};
