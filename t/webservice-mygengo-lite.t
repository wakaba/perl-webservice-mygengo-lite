package test::WebService::myGengo::Lite;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->subdir ('modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Test::More;
use HTTest::Mock;
use WebService::myGengo::Lite;

sub _new : Test(3) {
  my $ws = WebService::myGengo::Lite->new
      (api_key => q<abc def>, private_key => q<xyz aaa>);
  isa_ok $ws, 'WebService::myGengo::Lite';
  is $ws->api_key, q<abc def>;
  is $ws->private_key, q<xyz aaa>;
} # _new

__PACKAGE__->runtests;

1;

