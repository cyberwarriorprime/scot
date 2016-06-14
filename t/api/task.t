#!/usr/bin/env perl

use lib '../lib';
use lib '../../lib';

use Test::More;
use Test::Mojo;
use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);

$ENV{'scot_mode'}       = "testing";
$ENV{'SCOT_AUTH_TYPE'}  = "Testing";
$ENV{'scot_env_configfile'} = '../../../Scot-Internal-Modules/etc/scot_env_test.cfg';
print "Resetting test db...\n";
system("mongo scot-testing <../../etc/database/reset.js 2>&1 > /dev/null");

my @defgroups       = ( 'wg-scot-ir', 'wg-scot-testing' );

my $t   = Test::Mojo->new('Scot');

$t  ->post_ok  ('/scot/api/v2/event'  => json => {
        subject => "Entry Test Event 1",
        source  => ["threadtest"],
        status  => 'open',
    })
    ->status_is(200)
    ->json_is('/status' => 'ok');

my $event_id = $t->tx->res->json->{id};

$t  ->post_ok('/scot/api/v2/entry' => json => {
        body        => "Entry 1 on Event $event_id",
        target_id   => $event_id,
        target_type => "event",
        groups      => {
            read    => $defgroups,
            modify  => $defgroups,
        }
    })
    ->status_is(200)
    ->json_is('/status' => 'ok');

my $entry1 = $t->tx->res->json->{id};

$t  ->get_ok("/scot/api/v2/entry/$entry1" => {}, 
    "get to make sure entry is not task" )
    ->status_is(200)
    ->json_is('/is_task'        => 0);
  print Dumper($t->tx->res->json);
# make entry1 a task

$t  ->put_ok("/scot/api/v2/entry/$entry1" => json => {
    make_task => 1 })
    ->status_is(200);

# print Dumper($t->tx->res->json);
# done_testing();
# exit 0;

$t  ->get_ok("/scot/api/v2/entry/$entry1" => {}, 
    "Seeing if Entry $entry1 is now a task" )
    ->status_is(200)
    ->json_is('/is_task'        => 1)
    ->json_is('/task/status'    => 'open');

$t  ->put_ok("/scot/api/v2/entry/$entry1" => json => {
    take_task => 1 })
    ->status_is(200);

$t  ->get_ok("/scot/api/v2/entry/$entry1" => {}, 
    "Seeing if Entry $entry1 is now a task" )
    ->status_is(200)
    ->json_is('/is_task'        => 1)
    ->json_is('/task/status'    => 'assigned');

$t  ->put_ok("/scot/api/v2/entry/$entry1" => json => {
    close_task => 1 })
    ->status_is(200);

$t  ->get_ok("/scot/api/v2/entry/$entry1" => {}, 
    "Seeing if Entry $entry1 is now a task" )
    ->status_is(200)
    ->json_is('/is_task'        => 1)
    ->json_is('/task/status'    => 'closed');

$t  ->put_ok("/scot/api/v2/entry/$entry1" => json => {
    close_task => 1 })
    ->status_is(200);

$t  ->post_ok('/scot/api/v2/entry'    => json => {
        body        => "Entry 2 on event $event_id",
        target_id   => $event_id,
        target_type => "event",
        parent      => 0,
        groups      => {
            read    => $defgroups,
            modify  => $defgroups,
        }
    })
    ->status_is(200)
    ->json_is('/status' => 'ok');

my $entry2  = $t->tx->res->json->{id};

$t  ->get_ok("/scot/api/v2/event/$event_id/entry")
    ->status_is(200)
    ->json_is('/totalRecordCount' => 2)
    ->json_is('/records/0/id'   => $entry1)
    ->json_is('/records/1/id'   => $entry2);

$t  ->get_ok("/scot/api/v2/task")
    ->status_is(200);

#   print Dumper($t->tx->res->json);
 done_testing();
 exit 0;



