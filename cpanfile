requires 'perl', '5.008001';
requires 'Mojolicious';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Exception';
};
