=head1 Pulma::Core::DB

Part of Pulma system

Class for working with local DB (through DBI)

Copyright (C) 2011 Fedor A. Fetisov <faf@ossg.ru>. All Rights Reserved

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License

=cut

package Pulma::Core::DB;

use strict;
use warnings;

use Data::Dumper;
use Data::Structure::Util qw( unbless );
use DBI;

use Pulma::Service::Log;

# make Dumper output short (for logging)
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse = 1;

=head1 Method: new

=head2 Description

Class constructor

=head2 Argument(s)

=over

=item 1. (link to hash) configuration

=back

=head2 Returns

=over

=item (object) instance of class I<or> undef if initialization failed

=back

=head2 Configuration hash structure

{

    'driver' => <DBI driver to use>,

    'dsn' => <data source name> - string like
	     'dbname=<database name>;host=<host name>'
	     (or just filename in case of SQLite dastabase)

    'user' => <username to use for database connection>

    'passwd' => <password to use for database connection>,

    'autocommit' => <1|0> - flag to use autocommit, default: 0,

    'init' => [<list of commands to execute on connection>], default: []
	      list values could be given as scalars, arrays or hashes.
	      scalar will be classified as sql-query. in case of array, the
	      first element will be classified as query, while all others as
	      placeholders.
	      hash should be of special form:
		    {	'method' => <DBI method name>,
			'args' => [<arguments to call method with] }

}

=cut

sub new {
    my $package = shift;
    my $config = shift;

# initialize object frame
    my $self = {
	'connection' => undef,
	'requests' => {},
	'config' => $config,
	'name' => __PACKAGE__
    };

    $self->{'config'}->{'autocommit'} ||= 0;
    $self->{'config'}->{'init'} ||= [];

    $self = bless($self, $package);

# connect to database
    unless ($self->_connect()) {

        log_it( 'err',
		$self->{'name'} . "::new: can't connect to DB: %s",
		$DBI::errstr );

	unbless $self;

	return undef;

    }

    log_it('debug',  $self->{'name'} . '::new: connected to DB');

    return $self;
}

=head1 Method: execute

=head2 Description

Execute SQL-request to DB and retrieve result

=head2 Argument(s)

=over

=item 1. (link to hash) request parameters (optional parameter)

=item 2. (string) SQL-request (with DBI-style placeholders)

=item 3. (array) data to populate SQL-request with (using placeholders)

=back

=head2 Returns

=over

=item (link to hash) request result

=back

=head2 Structure of request parameters hash

{

    'cache' => 0 or 1 - flag to save prepared request in cache,

    'select' => 0 or 1 - whether request is selective or not (i.e. whether it
		should return some data or not),

    'commit' => 0 or 1 - optional flag to prevent request results from being
		commited to DB (naturally, this flag only takes effect if
		autocommit is disabled, see documentation on constructor
		configuration for details), default: 1

}

=head3 Default request parameters

{

    'cache' => 0,

    'select' => 0

}

=head2 Structure of request result hash

{

    'error' => <DBI error message> (if any error occured),

    'data' => [{}, ...] - array of anonymous hashes with selected data for
	      selective request

or
    'data' => 1 - for non-selective request

}

=cut

sub execute {
    my $self = shift;
    my $request = shift;

# set service request parameters
    my $params = {
		    '_retry' => 0
    };

# set basic request parameters
    if (ref($request) eq 'HASH') {
	$params->{'cache'} = $request->{'cache'} || 0;
	$params->{'select'} = $request->{'select'} || 0;
	$params->{'commit'} = $self->{'config'}->{'autocommit'} ?
			      1 :
			      ( exists($request->{'commit'}) ?
				$request->{'commit'} :
				1 );
	$request = shift;
    }

# execute request
    return $self->_request($params, $request, @_);
}

############################## Private methods ##################################

# Method: _request
# Description
#	Method to perform some SQL-request over DB
# Argument(s)
#	1. (link to hash) request parameters
#	2. (string) SQL-request
#	3. (array) arguments of SQL-request
# Returns
#	(link to hash) request result (see above in execute method)
#
# Structure of request parameters hash
#{
#	'_retry' => 0 or 1 - mark second try to execute DB request
#	for other keys - see above in execute method
# }

sub _request {
    my $self = shift;
    my $params = shift;
    my $request = shift;
    my @args = @_;

    my $result = {};

    log_it( 'debug',
	    $self->{'name'} . "::_request: request: %s, args: %s, params: %s",
	    $request, Dumper(\@args), Dumper(\$params) );

# check DB connection
    unless (defined $self->{'connection'}) {

	log_it( 'debug',
		$self->{'name'}  .
		    "::_request: connection to DB is dead. Try to restore." );

	unless($self->_connect()) {

	    return { 'error' => $DBI::errstr, 'data' => [] };

	}
	else {

	    log_it( 'debug',
		    $self->{'name'} .
			"::_request: connection to DB restored." );

	}

    }

# prepare request (if need to)
    unless ($self->{'requests'}->{$request}) {

	$self->{'requests'}->{$request} = $self->{'connection'}->prepare($request);

	log_it( 'debug',
		$self->{'name'} .
		    "::_request: request '%s' to DB prepared",
		$request );

    }

    if (!$self->{'requests'}->{$request}) {

	delete $self->{'requests'}->{$request};

# preparation failed - get error message and try failover variant if need to
	$result->{'error'} = $self->{'connection'}->errstr();

	log_it( 'info',
		$self->{'name'} .
		    "::_request: request '%s' preparation to DB failed. Error: %s",
		$request, $result->{'error'} );

	unless ( $params->{'_retry'} || $self->{'connection'}->ping() ) {

# it was first try and DB connection is dead (ping failed) - retry
	    log_it( 'debug',
		    $self->{'name'} .
			"_request: connection to DB is dead. Try to execute request '%s' once again.",
		    $request );

	    return $self->_retry($result, $params, $request, @args);

	}

	return $result;

    }

# execute request
    log_it( 'debug',
	    $self->{'name'} .
		"::_request: executing request '%s' to DB",
	    $request );

    my $success = $self->{'requests'}->{$request}->execute(@args) ? 1 : 0;
    if ($success) {

# request execution succeed
	log_it( 'debug',
		$self->{'name'} .
		    "::_request: request '%s' to DB executed successfully",
		$request );

	$result->{'data'} = [];
	if ($params->{'select'}) {

	    log_it( 'debug',
		    $self->{'name'} .
			"::_request: obtaining data after selective request '%s' to DB",
		    $request );

# for selective request - obtain resulting data and place it into resulting hash
	    while (my $row = $self->{'requests'}->{$request}->fetchrow_hashref()) {
		push(@{$result->{'data'}}, $row);
	    }

	    if ($self->{'requests'}->{$request}->err()) {

# something went wrong while obtaining resulting data - get error message,
# rollback all changes and try failover variant if need to
		$result->{'error'} = $self->{'requests'}->{$request}->errstr();

		log_it( 'info',
			$self->{'name'} .
			    "::_request: obtaining data after request '%s' to DB failed. Error: %s",
			$request, $result->{'error'} );

		 unless ($self->{'config'}->{'autocommit'}) {

		    log_it( 'debug',
			    $self->{'name'} .
				"::_request: rolling back all changes made to DB" );

		    $self->{'connection'}->rollback();

		}

		unless ( $params->{'_retry'} || $self->{'connection'}->ping() ) {
# it was first try and DB connection is dead (ping failed) - retry

		    log_it( 'debug',
			    $self->{'name'} .
				"::_request: connection to DB is dead. Try to execute request '%s' once again.",
			    $request );

		    return $self->_retry($result, $params, $request, @args);

		}

	    }
	    elsif (!$self->{'config'}->{'autocommit'} && $params->{'commit'}) {

# everything fine, data from selective result obtained - commit changes to DB
		log_it( 'debug',
			$self->{'name'} .
			    "::_request: commiting data after selective request '%s' to DB",
			$request );

		$self->{'connection'}->commit();

	    }
	}
	else {
# everything fine, non-selective request succeed - commit changes to DB
	    $result->{'data'} = 1;

	    if (!$self->{'config'}->{'autocommit'} && $params->{'commit'}) {

		log_it( 'debug',
			$self->{'name'} .
			    "::_request: commiting data after non-selective request '%s' to DB",
			$request );

		$self->{'connection'}->commit();

	    }

	}

    }
    else {

# request execution failed - get error message, rollback changes and try failover
# variant if need to
	$result->{'error'} = $self->{'requests'}->{$request}->errstr();

	log_it( 'info',
		$self->{'name'} .
		    "::_request: execution of request '%s' to DB failed. Error: %s",
		$request, $result->{'error'} );

	unless ($self->{'config'}->{'autocommit'}) {

	    log_it( 'debug',
		    $self->{'name'} .
			"::_request: rolling back all changes made to DB" );

	    $self->{'connection'}->rollback();

	}

	unless ( $params->{'_retry'} || $self->{'connection'}->ping() ) {
# it was first try and DB connection is dead (ping failed) - retry

	    log_it( 'debug',
		    $self->{'name'} .
			"::_request: connection to DB is dead. Try to execute request '%s' once again.",
		    $request );

	    return $self->_retry($result, $params, $request, @args);

	}

    }

# destroy request object if it should not be cached
    unless ($params->{'cache'}) {
	$self->{'requests'}->{$request}->finish();
	delete $self->{'requests'}->{$request};
    }

    return $result;
}

# Method: _retry
# Description
#	Method to retry to perform SQL-request over DB whose connection was
#	closed
# Argument(s)
#	1. (link to hash) previous attempt's result
#	2. (link to hash) request parameters
#	3. (string) SQL-request
#	4. (array) arguments of SQL-request
# Returns
#	(link to hash) previous attempt's result if DB reconnection fails,
#	or otherwise - SQL-request's result
#
# Structure of request parameters' hash
#	see above in _request method
#
# Structure of request result hash and previous attempt's result
#	see above in _request method

sub _retry {
    my $self = shift;
    my $old_result = shift;
    my $params = shift;
    my $request = shift;
    my @args = @_;

    log_it( 'debug',
	    $self->{'name'} .
		"::_retry: second try for request: %s, args: %s, params: %s",
	    $request, Dumper(\@args), Dumper(\$params) );

# try to reconnect to DB
    unless ($self->_reconnect()) {

	log_it( 'debug',
		$self->{'name'} .
		    "::_retry: reconnection to DB failed. Second try for request '%s' failed.",
		$request );

	return $old_result;

    }

# reconnection succeed, try to execute SQL-request for the second time
    log_it( 'debug',
	    $self->{'name'} .
		"::_retry: reconnection to DB succeed. Launch second try for request '%s'",
	    $request );

    $params->{'_retry'} = 1;

    return $self->_request($params, $request, @args);
}

# Method: _reconnect
# Description
#	Method to reopen connection to DB
# Argument(s)
#	none
# Returns
#	1 on successful reconnection, 0 - otherwise

sub _reconnect {
    my $self = shift;

    log_it('debug', $self->{'name'} . "::_reconnect: reconnecting to DB");

    return $self->_disconnect() && $self->_connect();
}

# Method: _connect
# Description
#	Method to open connection to DB
# Argument(s)
#	none
# Returns
#	1 on successful connection, 0 - otherwise

sub _connect {
    my $self = shift;

    log_it('debug', $self->{'name'} . "::_connect: connecting to DB");

    my $result = undef;
    eval {

	my $options = { RaiseError => 0,
			PrintError => 0,
			AutoCommit => $self->{'config'}->{'autocommit'} || 0,
			ChopBlanks => 1
	};

	if ($self->{'config'}->{'driver'} eq 'SQLite') {
	    $options->{sqlite_unicode} = 1;
	}
	elsif ($self->{'config'}->{'driver'} eq 'mysql') {
	    $options->{mysql_enable_utf8} = 1;
	}

	unless ( $self->{'connection'} = DBI->connect(
						    'dbi:' . $self->{'config'}->{'driver'} .
						    ':' . $self->{'config'}->{'dsn'},
						    $self->{'config'}->{'user'},
						    $self->{'config'}->{'passwd'},
						    $options ) ) {

	    log_it( 'err',
		    $self->{'name'} . "::_connect: can't connect to DB: %s",
		    $DBI::errstr );

	    $result = 0;

	}
	else {

	    log_it( 'debug',
		    $self->{'name'} .
			"::_connect: successfully connected to DB" );

	    $result = 1;

	}

    };

    unless (defined $result) {

	log_it( 'err',
		$self->{'name'} . "::_connect: can't connect to DB: %s",
		$@ );

	$result = 0;

    }

# connection failed, nothing to do here
    return $result unless $result;

    log_it( 'debug',
	    $self->{'name'} .
		"::_connect: executing initial commands" );

# execute initial commands (if need to)
    my $counter = 0;
    foreach my $command (@{$self->{'config'}->{'init'}}) {

	$counter++;

	if ( (ref($command) eq '') || (ref($command) eq 'ARRAY') ) {

	    my $res = undef;

	    if (ref($command) eq 'ARRAY') {

		my $cmd = shift(@$command);
		if (scalar(@$command)) {

		    $res = $self->{'connection'}->do($cmd, undef, @{$command});

		}
		else {

		    $res = $self->{'connection'}->do($cmd);

		}

	    }
	    else {

		$res = $self->{'connection'}->do($command);

	    }

	    if (defined $res) {

		log_it( 'debug',
			$self->{'name'} .
			    "::_connect: init command number %s successfully executed",
			$counter );

		unless ($self->{'config'}->{'autocommit'}) {

		    $self->{'connection'}->commit();

		}

	    }
	    else {

		log_it( 'err',
			$self->{'name'} .
			    "::_connect: failed to execute initial command number %s: %s",
			$counter, $self->{'connection'}->errstr() );

		unless ($self->{'config'}->{'autocommit'}) {

		    $self->{'connection'}->rollback();

		}

	    }

	}
	elsif (ref($command) eq 'HASH') {
	    if ( exists($command->{'method'}) &&
		 (ref($command->{'method'}) eq '') &&
		 exists($command->{'args'}) &&
		 (ref($command->{'args'}) eq 'ARRAY') ) {

		my $method = $command->{'method'};
		my $res = $self->{'connection'}->$method($command->{'args'});

		log_it( 'debug',
			$self->{'name'} .
			    "::_connect: init method number %s called, got result: %s",
			$counter, Dumper($res) );

		unless ($self->{'config'}->{'autocommit'}) {

		    $self->{'connection'}->commit();

		}

	    }
	    else {

		log_it( 'err',
			$self->{'name'} .
			    "::_connect: failed to execute initial command number %s: invalid hash structure",
			$counter );

		unless ($self->{'config'}->{'autocommit'}) {

		    $self->{'connection'}->rollback();

		}

	    }
	}
	else {

	    log_it( 'err',
		    $self->{'name'} .
			"::_connect: failed to execute initial command number %s: expected scalar, array, or hash, got %s",
		    $counter, ref($command) );
	}

    }

    return $result;
}

# Method: _disconnect
# Description
#	Method to close DB connection
# Argument(s)
#	none
# Returns
#	1 on successful disconnection, 0 - otherwise

sub _disconnect {
    my $self = shift;

    log_it('debug', $self->{'name'} . "::_disconnect: disconnecting from DB");

    if (defined $self->{'connection'}) {

	if ( !$self->{'config'}->{'autocommit'} &&
	     $self->{'connection'}->ping() ) {

# rollback all uncommited changes if connection wasn't lost
	    log_it( 'debug',
		    $self->{'name'} .
			"::_disconnect: rolling back all changes made to DB" );

	    my $res = $self->{'connection'}->rollback();

	    log_it( 'err',
		    $self->{'name'} .
			"::_disconnect: error while rolling back changes: %s",
		    $self->{'connection'}->errstr() ) unless $res;

	}

    }

# finish all cached requests for a given DB
    log_it( 'debug',
	    $self->{'name'} . "::_disconnect: finishing all requests to DB" );

    foreach my $req (keys %{$self->{'requests'}}) {

	if (defined $self->{'requests'}->{$req}) {

	    my $res = $self->{'requests'}->{$req}->finish();

	    log_it( 'err',
		    $self->{'name'} .
			"::_disconnect: error while finishing request: %s",
		    $self->{'requests'}->{$req}->errstr() ) unless $res; # hope, this works as i thought

	}

	delete $self->{'requests'}->{$req};

    }

# finally close connection
    if (defined $self->{'connection'}) {

	log_it( 'debug',
		$self->{'name'} .
		    "::_disconnect: finally closing connection to DB" );

	my $res = $self->{'connection'}->disconnect() ? 1 : 0;

	delete $self->{'connection'};
	$self->{'connection'} = undef;

	return $res;

    }
    else {

	log_it( 'debug',
		$self->{'name'} .
		    "::_disconnect: connection to DB is already closed" );

	return 1;

    }
}

# Method: DESTROY
# Description
#	Class destructor
# Argument(s)
#	none
# Returns
#	none

sub DESTROY {
    my $self = shift;

    log_it('debug', $self->{'name'} . '::DESTROY: DB object destruction');

# correctly close DB connection
    $self->_disconnect();
}

1;
