{
    package Foo;
    use Mojo::Base -base;

    has 'bar';
    has 'ua';

    sub new {
        my $self = shift->SUPER::new(@_);
        $self->{ __id } = rand;
        return $self;
    }
}

{
    package Bar;
    use Mojo::Base -base;

    has 'baz';

    sub new {
        my $self = shift->SUPER::new(@_);
        my ( $string, $baz, $number, $cb ) = @_;
        $self->{ baz } = $baz;
        $cb->( $string, $baz, $number );
        return $self;
    }
}

{
    package Baz;
    use Mojo::Base -base;
}

use strict;
use Test::More 0.98;
use Test::Exception;

use Mojolicious;

# http://stackoverflow.com/questions/1748896/in-perl-how-do-i-put-multiple-packages-in-a-single-pm-file
import Foo;
import Bar;
import Baz;

$ENV{'MOJO_LOG_LEVEL'} = 'fatal';

my $app;
my $fooService;
my $fooService2;

$app = Mojolicious->new;
$app->plugin( 'ServiceContainer', {
    'foo' => {
        class => 'Foo',
        args => { 'bar' => '$bar', 'ua' => '$ua' }
    },
    'bar' => {
        class => 'Bar',
        args => [ 'secretString', '$baz', 1, sub {
            my ( $string, $baz, $number ) = @_;
            ok( $string == 'secretString', 'first argument' );
            isa_ok $baz, 'Baz';
            ok( $number == 1, 'third argument' );
        } ]
    },
    'baz' => { class => 'Baz' },
    'alpha' => {},
    'ua' => {
        helper => 'ua'
    }
} );

throws_ok sub { $app->service( 'FOO2' ); },
    qr /Unknown service: foo2/,
    'throw when trying to load a service that is not defined';

lives_ok sub { $app->service( 'foo' ); },
    'no exception while trying to load a registered service';

$fooService = $app->service( 'foo' );
is_deeply $fooService, $app->service( 'FOO' ),
    'service names can be case-insensitive';

isa_ok $app->service( 'ua' ), 'Mojo::UserAgent', 'service($ua)';

throws_ok sub { $app->service( 'alpha' ); },
    qr /Service alpha does not have an associated class specified./,
    'throw when trying to load a service without a class or helper specified';

lives_ok sub { $app->service( 'baz' ); },
    'no exception while trying to load a service with no args';

$fooService2 = $app->service( 'foo' );
isa_ok( $fooService2->bar, 'Bar', 'Foo::bar' );
isa_ok( $fooService2->bar->baz, 'Baz', 'Foo::bar::baz' );
ok( $fooService->{ __id } == $fooService2->{ __id },
    'use created instance on subsequent calls to load.' );

done_testing;
