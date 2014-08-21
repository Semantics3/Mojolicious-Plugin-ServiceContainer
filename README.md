# NAME

Mojolicious::Plugin::ServiceContainer - A Dependency Injection Container implementation.

# SYNOPSIS

For a regular Mojolicious application, you can load this plugin using the `plugin` method.

    $self->plugin( 'ConfigApi' );
    $self->plugin( 'ServiceContainer' );

For a Mojolicious::Lite application, you can use the `plugin` directive.

    plugin 'ConfigApi';
    plugin 'ServiceContainer';

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

The dependencies between services are listed in the application's configuration file under the `services` field.
For example, if you are using the [Mojolicious::Plugin::YamlConfig](https://metacpan.org/pod/Mojolicious::Plugin::YamlConfig) plugin, your configuration file might 
look something like this:

    ...
    - services:
          google_auth:
              class: 'MyGoogleAuthService'
              args:
                  client_id: xxxx.xxxx.xxxx.xxxx
                  client_secret: xxxx.xxxx.xxxx.xxxx
                  ua: '$ua'
                  log: '$log'
          mongo:
              class: 'Mango'
              args:
                  - 'mongodb://localhost'
          ua:
              class: Mojo::UserAgent
              helper: 'ua'
          log:
              class: Mojo::Log
              helper: 'log'
    ...

The service definitions are contained in a `services` object. Each key of the object is the name used to refer 
to a given service within your application.

Each service definition may have one or more of the following keys:

- `class` _required_ **string**: Name of the class (i.e. module) that the service is referring to.
- `helper` _optional_ **string**: Name of the factory helper method that will already return the service object 
when called. The usefulness of this option depends on the other plugins that your application is using.
- `args` _optional_ **arrayref** or **hashref**: The dependencies of your service. Static values will be 
passed as is to the constructor of the service. Dependent services are referred to by their names prefixed 
by the `$` sign. Eg. `$mongo`. Dependent services are first resolved (i.e. their own dependencies are 
resolved) before they are injected into the original service's constructor.

As the services definitions are listed in the configuration file, they are immutable during the runtime of 
your application.

# HELPERS

## service

    my $authService = $c->service( 'google_auth' );

Inside any of your controllers, you can inject a service object by using the `service` helper. The only 
argument passed is the name of the service as given in the service definition.

# METHODS

[Mojolicious::Plugin::ServiceContainer](https://metacpan.org/pod/Mojolicious::Plugin::ServiceContainer) inherits all methods from [Mojolicious::Plugin](https://metacpan.org/pod/Mojolicious::Plugin).

# LICENSE

Copyright (C) 2014 Semantics3 Inc.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Amarnath Ravikumar <amar@semantics3.com>
