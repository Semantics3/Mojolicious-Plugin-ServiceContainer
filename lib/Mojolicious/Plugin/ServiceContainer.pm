#!/usr/bin/env perl

package Mojolicious::Plugin::ServiceContainer;

use 5.012;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Exception;
use Mojo::Loader qw( load_class );

our $VERSION = "1.0.1";

sub register {
    my ( $plugin, $app, $config ) = @_;

    our $serviceConfig = $config // {};
    $app->log->debug( 'Registering the ServiceContainer plugin.' );

    #------------------------------------------------------------------------------
    # Recursively resolves a set of service dependencies.
    #------------------------------------------------------------------------------
    # - Dependencies can either be represented either as an arrayref or a hashref.
    # - If one of the dependencies is itself a service (string prefixed by a $),
    #   it is first resolved before the next dependency is inspected. In other
    #   words, the dependency tree is traversed in a depth-first manner.
    #------------------------------------------------------------------------------
    # $c - Mojolicious Controller.
    # $args - Dependencies
    #------------------------------------------------------------------------------
    # Either returns a reference the type of which matches the type of $args passed
    # (or) throws an exception if any of the service dependencies is not valid.
    #------------------------------------------------------------------------------
    sub _resolve {
        my ( $c, $args ) = @_;
        $args //= {};
        while ( my ( $index, $arg ) = each $args ) {
            #-- We only care about service dependencies i.e. the deps starting with a $.
            if ( substr( $arg, 0, 1 ) eq '$' ) {
                my $name = substr( $arg, 1 );
                if ( ref( $args ) eq 'ARRAY' ) {
                    $args->[$index] = _inject( $c, $name );
                }
                elsif ( ref( $args ) eq 'HASH' ) {
                    $args->{$index} = _inject( $c, $name );
                }
            }
        }
        return $args;
    }

    #------------------------------------------------------------------------------
    # Builds and sends back a service object for a given service.
    #------------------------------------------------------------------------------
    # - A service is identified by its name passed. The name passed must match one
    #   of the service definitions for it to be considered a valid service.
    # - Sends the cached version of the object if it has already been built
    #   at some point in the application lifecycle before.
    #------------------------------------------------------------------------------
    # $c - Mojolicious Controller.
    # $name - Name of the service.
    #------------------------------------------------------------------------------
    # Either returns a service object
    # (or) throws an exception if any of the service dependencies is not valid.
    #------------------------------------------------------------------------------
    sub _inject {
        my ( $c, $name ) = @_;
        $name = lc $name;

        state $serviceObjectCache = {};

        #-- Exit early if we can find a service object in our cache.
        if ( defined( $serviceObjectCache->{$name} ) ) {
            return $serviceObjectCache->{$name};
        }

        #-- Check if a service has been registered with the given name.
        if ( !defined( $serviceConfig->{$name} ) ) {
            Mojo::Exception->throw( sprintf( 'Unknown service: %s', $name ) );
        }

        #-- Exit early if there is a helper that we can use.
        if ( defined( $serviceConfig->{$name}->{helper} ) ) {
            my $helper = $serviceConfig->{$name}->{helper};
            $serviceObjectCache->{$name} = $c->app->$helper();
            $c->app->log->debug( sprintf( 'Used object from helper %s for the %s service.', $helper, $name ) );
            return $serviceObjectCache->{$name};
        }

        #-- Ensure found service has been mapped to a class.
        if ( !defined( $serviceConfig->{$name}->{class} ) ) {
            Mojo::Exception->throw(
                sprintf( 'Service %s does not have an associated class specified.', $name )
            );
        }

        my $class = $serviceConfig->{$name}->{class};
        if ( $class =~ /Mojolicious/ ) {
            #-- If a service has Mojolicious as a dependency, return a reference to the current app.
            $serviceObjectCache->{$name} = $c->app;
            return $serviceObjectCache->{$name};
        }

        my $e = load_class $class;
        die qq{ Loading "$class" failed: $e } if $e;

        my $args = _resolve( $c, $serviceConfig->{$name}->{args} );
        if ( ref( $args ) eq 'ARRAY' ) {
            $serviceObjectCache->{$name} = $class->new( @$args ) ;
        }
        else {
            $serviceObjectCache->{$name} = $class->new( $args );
        }

        $c->app->log->debug( sprintf( 'Built an object of %s for the %s service.', $class, $name ) );

        return $serviceObjectCache->{$name};
    }

    # ---------------------------------------------------------------------------
    # Helpers.
    # ---------------------------------------------------------------------------
    $app->helper( service => sub {
        _inject( @_ );
    } );
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::ServiceContainer - A Dependency Injection Container for Mojolicious.

=for html <a href="https://travis-ci.org/Semantics3/Mojolicious-Plugin-ServiceContainer"><img src="https://travis-ci.org/Semantics3/Mojolicious-Plugin-ServiceContainer.svg?branch=master"></a>

=head1 SYNOPSIS

For a regular L<Mojolicious> application, you can load this plugin using the C<plugin> method:

  $self->plugin( 'ServiceContainer', {} );

For a L<Mojolicious::Lite> application, you can use the C<plugin> directive:

  plugin 'ServiceContainer' => {};

=head1 DESCRIPTION

L<Mojolicious::Plugin::ServiceContainer> is a minimal Dependency Injection Container implementation for
L<Mojolicious>.

A service, for the purposes of this plugin, is defined as a I<class> (any module that inherits from L<Mojo::Base>),
which is responsible for performing a single role within your application. A service class must be
instantiable by simply doing a C<MyService-E<gt>new> call. Database connections, Email senders, HTTP clients can be
considered as services.

A service object is an instance of the service class. An assumption that is taken here is that a single service
object for a given service is sufficient for the runtime of the application. In a future version, the API might
permit the creation of more service objects for the same service.

The service definitions are loaded along with the plugin:

    plugin 'ServiceContainer' => {
      google_auth => {
        class => 'MyGoogleAuthService',
        args => {
          client_id => 'xxxx.xxxx.xxxx.xxxx',
          client_secret => 'yyyy.yyyy.yyyy.yyyy',
          ua => '$ua',
          log => '$log'
        }
      },
      mongo => {
        class => 'Mango',
        args => [
          'mongodb://localhost'
        ]
      },
      ua => {
        helper => 'ua'
      },
      log => {
        helper => 'log'
      }
    }

Each service definition may have one or more of the following keys:

=over 4

=item *
C<class> B<string>: Name of the class (i.e. module) that the service is referring to.

B<Note>: If your class is C<Mojolicious>, you will be passed a reference to the running application and not
a new instance of the C<Mojolicious> class like other services. This is a way by which you can use the
application helpers from within your service.

=item *
C<helper> I<optional> B<string>: Name of a Mojolicious helper method that behaves like a factory and will return
a service object when called. The helper will be called in the context of the L<Mojolicious> application object.
You can use any relevant default helper or a custom one. The assumption here is that the helper will return the
same singleton everytime but this may or may not be the case depending on the helper implementation.

=item *
C<args> I<optional> B<arrayref> or B<hashref>: The dependencies of your service. Static values will be
passed as is to the constructor of the service. Dependent services are referred to by their names prefixed
by the C<$> sign. Eg. C<$mongo>. Dependent services are first resolved (i.e. their own dependencies are
resolved) before they are injected into the original service's constructor.

=back

As the service definitions are listed in the configuration file, they are immutable during the runtime of
your application.

=head1 HELPERS

=head2 service

  my $authService = $c->service( 'google_auth' );

Inside any of your controllers, you can inject a service object by using the C<service> helper. The only
argument passed is the name of the service as given in the service definition.

=head1 METHODS

L<Mojolicious::Plugin::ServiceContainer> inherits all methods from L<Mojolicious::Plugin>.

=head1 LICENSE

Copyright (C) 2016 Semantics3 Inc.

=head1 AUTHOR

Amarnath Ravikumar E<lt>amar@semantics3.comE<gt>

=cut
