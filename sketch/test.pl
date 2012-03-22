#!/usr/bin/perl
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->subdir ('modules', '*', 'lib')->stringify;
BEGIN {
  unshift @INC, split /:/, scalar file (__FILE__)->dir->parent->file ('config', 'perl', 'libs.txt')->slurp;
  $ENV{WEBUA_DEBUG} = 2;
}
use WebService::myGengo::Lite;

my $keys_f = file (__FILE__)->dir->file ('keys.txt');
my ($api_key, $private_key) = split /\n/, scalar $keys_f->slurp;

my $ws = WebService::myGengo::Lite->new
    (api_key => $api_key,
     private_key => $private_key);

#$ws->account_stats;

my $job = $ws->create_job_request
    (source => {body => 'Hello, world! 2', lang => 'en'},
     target => {lang => 'ja'},
     tier => 'machine');
my $job2 = $ws->create_job_request
    (source => {body => 'Hello! 2', lang => 'en'},
     target => {lang => 'ja'},
     tier => 'machine');

#my $data = $ws->job_comment_post (173522, comment_for_translator => 'Difficult!');
#my $data = $ws->job_comments ('173522');
my $data = $ws->job_revision_list ('173522');
my $data = $ws->job_revision ('173522', 387840);
#my $data = $ws->job_feedback ('173522');

#my $data = $ws->jobs_post ([$job, $job2], as_group => 0);
#my $data = $ws->jobs_get (count => 3, timestamp_after => time, status => 'rejected');

#my $data = $ws->job_get (173522);

#$data = $data->job;
$data = $data->data;

use Data::Dumper;
warn Dumper $data;
