# NAME

Mojolicious::Plugin::ServiceContainer - A Dependency Injection Container for Mojolicious.

<div>
    <a href="https://travis-ci.org/Semantics3/Mojolicious-Plugin-ServiceContainer"><img src="https://travis-ci.org/Semantics3/Mojolicious-Plugin-ServiceContainer.svg?branch=master"></a>
</div>

# SYNOPSIS

For a regular [Mojolicious](https://metacpan.org/pod/Mojolicious) application, you can load this plugin using the `plugin` method:

    $self->plugin( 'ServiceContainer', {} );

For a [Mojolicious::Lite](https://metacpan.org/pod/Mojolicious::Lite) application, you can use the `plugin` directive:

    plugin 'ServiceContainer' => {};

# DESCRIPTION

[Mojolicious::Plugin::ServiceContainer](https://metacpan.org/pod/Mojolicious::Plugin::ServiceContainer) is a minimal Dependency Injection Container implementation for
[Mojolicious](https://metacpan.org/pod/Mojolicious).

A service, for the purposes of this plugin, is defined as a _class_ (any module that inherits from [Mojo::Base](https://metacpan.org/pod/Mojo::Base)),
which is responsible for performing a single role within your application. A service class must be
instantiable by simply doing a `MyService->new` call. Database connections, Email senders, HTTP clients can be
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

- `class` **string**: Name of the class (i.e. module) that the service is referring to.

    **Note**: If your class is `Mojolicious`, you will be passed a reference to the running application and not
    a new instance of the `Mojolicious` class like other services. This is a way by which you can use the
    application helpers from within your service.

- `helper` _optional_ **string**: Name of a Mojolicious helper method that behaves like a factory and will return
a service object when called. The helper will be called in the context of the [Mojolicious](https://metacpan.org/pod/Mojolicious) application object.
You can use any relevant default helper or a custom one. The assumption here is that the helper will return the
same singleton everytime but this may or may not be the case depending on the helper implementation.
- `args` _optional_ **arrayref** or **hashref**: The dependencies of your service. Static values will be
passed as is to the constructor of the service. Dependent services are referred to by their names prefixed
by the `$` sign. Eg. `$mongo`. Dependent services are first resolved (i.e. their own dependencies are
resolved) before they are injected into the original service's constructor.

As the service definitions are listed in the configuration file, they are immutable during the runtime of
your application.

# HELPERS

## service

    my $authService = $c->service( 'google_auth' );

Inside any of your controllers, you can inject a service object by using the `service` helper. The only
argument passed is the name of the service as given in the service definition.

# METHODS

[Mojolicious::Plugin::ServiceContainer](https://metacpan.org/pod/Mojolicious::Plugin::ServiceContainer) inherits all methods from [Mojolicious::Plugin](https://metacpan.org/pod/Mojolicious::Plugin).

# LICENSE

Copyright (C) 2016 Semantics3 Inc.

# AUTHOR

Amarnath Ravikumar <amar@semantics3.com>
