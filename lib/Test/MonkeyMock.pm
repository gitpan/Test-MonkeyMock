package Test::MonkeyMock;

use strict;
use warnings;

require Carp;

our $VERSION = '0.01';

sub new {
    my $class = shift;
    $class = ref $class if ref $class;
    my ($instance) = @_;

    my $self = { instance => $instance };
    bless $self, $class;

    return $self;
}

my $magic_counter = 0;

sub mock {
    my $self = shift;
    my ( $method, $code ) = @_;

    if ( my $instance = $self->{instance} ) {
        Carp::croak("Unknown method '$method'")
          unless $self->can($method);

        my $new_package = ref($self) . '::' . ref($instance) . $magic_counter++;

        no strict 'refs';
        @{ $new_package . '::ISA' } = ( ref($instance) );
        *{ $new_package . '::' . $method } = $code;

        bless $instance, $new_package;

        $self->{instance} = $instance;
    }
    else {
        my $mocks = $self->{mocks} ||= {};
        $mocks->{$method} = $code;
    }

    return $self;
}

sub mocked_instance {
    my $self = shift;

    return $self->{instance};
}

sub mocked_called {
    my $self = shift;
    my ($method) = @_;

    my $mocks = $self->{mocks} ||= {};
    my $calls = $self->{calls} ||= {};

    if ( $self->{instance} ) {
        Carp::croak("Unknown method '$method'")
          unless $self->can($method);
    }
    else {
        Carp::croak("Unmocked method '$method'")
          unless exists $mocks->{$method};
    }

    return $calls->{$method}->{called} || 0;
}

sub mocked_call_args {
    my $self = shift;
    my ( $method, $frame ) = @_;

    $frame ||= 0;

    my $stack = $self->mocked_call_stack($method);

    Carp::croak("Unknown frame '$frame'")
      unless @$stack > $frame;

    return @{$stack->[$frame]};
}

sub mocked_call_stack {
    my $self = shift;
    my ( $method ) = @_;

    Carp::croak("Method is required") unless $method;

    my $calls = $self->{calls} ||= {};
    my $mocks = $self->{mocks} ||= {};

    if ( $self->{instance} ) {
        Carp::croak("Unknown method '$method'")
          unless $self->can($method);
    }
    else {
        Carp::croak("Unmocked method '$method'")
          unless exists $mocks->{$method};
    }

    Carp::croak("Method '$method' was not called")
      unless exists $calls->{$method};

    return $calls->{$method}->{stack};
}

sub can {
    my $self = shift;
    my ($method) = @_;

    if ( $self->{instance} ) {
        return $self->{instance}->can($method);
    }
    else {
        my $mocks = $self->{mocks} ||= {};
        return exists $mocks->{$method};
    }
}

our $AUTOLOAD;

sub AUTOLOAD {
    my $self = shift;

    my ($method) = ( split /::/, $AUTOLOAD )[-1];

    return if $method =~ /^[A-Z]+$/;

    my $calls = $self->{calls} ||= {};
    my $mocks = $self->{mocks} ||= {};

    $calls->{$method}->{called}++;
    push @{ $calls->{$method}->{stack} }, [@_];

    Carp::croak("Unmocked method '$method'")
      if !$self->{instance} && !exists $mocks->{$method};

    if ( $self->{instance} ) {
        return $self->{instance}->$method(@_);
    }
    else {
        return $mocks->{$method}->( $self, @_ );
    }
}

1;
__END__

=pod

=head1 NAME

Test::MonkeyMock - Usable mock class

=head1 SYNOPSIS

    # Create a new mock object
    my $mock = Test::MonkeyMock->new;
    $mock->mock(foo => sub {'bar'});
    $mock->foo;

    # Mock existing object
    my $mock = Test::MonkeyMock->new(MyObject->new());
    $mock->mock(foo => sub {'bar'});
    $mock->foo;

    # Check how many times the method was called
    my $count = $mock->mocked_called('foo');

    # Check what arguments were passed on the first call
    my @args = $mock->mocked_call_args('foo');

    # Check what arguments were passed on the second call
    my @args = $mock->mocked_call_args('foo', 1);

    # Get all the stack
    my $call_stack = $mock->mocked_call_stack('foo');

=head1 DESCRIPTION

Why? I used and still use L<Test::MockObject> and L<Test::MockObject::Extends>
a lot but sometimes it behaves very strangely introducing hard to find global
bugs in the test code, which is very painful, since the test suite should have
as least bugs as possible. L<Test::MonkeyMock> is somewhat a subset of
L<Test::MockObject> but without side effects.

L<Test::MonkeyMock> is also very strict. When mocking a new object:

=over

=item * throw when using C<mocked_called> on unmocked method

=item * throw when using C<mocked_call_args> on unmocked method

=back

When mocking an existing object:

=over

=item * throw when using C<mock> on unknown method

=item * throw when using C<mocked_called> on unknown method

=item * throw when using C<mocked_call_args> on unknown method

=back

=head1 AUTHOR

Viacheslav Tykhanovskyi, C<vti@cpan.org>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2013, Viacheslav Tykhanovskyi

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
