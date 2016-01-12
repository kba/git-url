package Foo;

sub new {
    $self = bless {}, 'Foo';
    *Foo::name = sub { return 'foo' };
    return $self;
}

package main;
$obj = Foo->new();
warn $obj->name;
warn $obj->ref;

