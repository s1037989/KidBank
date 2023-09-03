use Mojo::Base -strict, -signatures;

use Test::More;
use Test::Mojo;
use Term::ANSIColor;

# Override configuration for testing
my $t = Test::Mojo->new('KidBank');
my $capture = $t->app->log->capture('trace');

$t->get_ok('/')->status_is(302)->header_is(location => '/login');
$t->get_ok('/login')->status_is(200);

done_testing;