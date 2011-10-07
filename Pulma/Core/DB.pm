#
# Copyright (C) 2011 Fedor A. Fetisov <faf@ossg.ru>. All Rights Reserved
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package Pulma::Core::DB;

use strict;
use warnings;

use Data::Dumper;
use Data::Structure::Util qw( unbless );
use DBI;

use Pulma::Service::Log;

# make Dumper output short for syslog
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse = 1;

# Method: new
# Description: constructor
# Argument(s): 1: config (link to hash)
# Return: object or undef in case of any error
#
# Config hash structure:
# {
#			'driver' => string - DBI driver to use
#			'dsn' => string - DSN name - i.e. string like 'dbname=<database name>;host=<host name>'
#							(or just filename in case of SQLite dastabase)
#			'user' => string - DB user
#			'passwd' => string - password of the DB user
# }
sub new {
    my $package = shift;
    my $config = shift;

# initialize object frame
    my $self = {
	'connection' => undef,
	'requests' => {},
	'config' => $config
    };

    $self = bless($self, $package);

# connect to database
    unless ($self->_connect()) {
        log_it('err', __PACKAGE__ . "::new: can't connect to DB: %s", $DBI::errstr);
	unbless $self;
	return undef;
    }
    log_it('debug',  __PACKAGE__ . '::new: connected to DB');

    return $self;
}

# Method: get
# Description: get data from read-DB with SQL-request
# Argument(s): [1: parameters of request (link to hash)], 2: request (string), 3, ...: arguments of request (to replace DBI-placeholders with)
# Return: request result (link to hash)
#
# Structure of request parameters' hash:
# {	'cache' => 0 or 1 - flag to save prepared request in cache
#	'select' => 0 or 1 - whether request is select or not (i.e. should it return some data or not)
# }
#
# Structure of request result hash: see below in _request method (it's the same)
sub execute {
    my $self = shift;
    my $request = shift;
    my $params = {
		    '_retry' => 0
    };
    if (ref($request) eq 'HASH') {
	$params->{'cache'} = $request->{'cache'} || 0;
	$params->{'select'} = $request->{'select'} || 0;
	$request = shift;
    }

    return $self->_request($params, $request, @_);
}

# Method: _request
# Description: perform some SQL-request over given DB
# Argument(s): 1: request parameters (link to hash), 2: request (string), 3, ...: arguments of request
# Return: request result (link to hash)
#
# Structure of request parameters hash:
# {
#	'_db' => string - database to send request to (i.e. either 'read' or 'write')
#	'_retry' => 0 or 1 - mark second try to execute DB request
#	for other keys - see above in get method (it's all the same)
# }
# Structure or request result:
# {
#	'error' => string - DBI error message (if any error occured)
#	'data' => [] - array of anonymous hashes with obtained data for selective request
# or
#	'data' => 1 - for non-selective request
# }
sub _request {
    my $self = shift;
    my $params = shift;
    my $request = shift;
    my @args = @_;

    my $result = {};

    log_it('debug', __PACKAGE__ . "::_request: request: %s, args: %s, params: %s", $request, Dumper(\@args), Dumper(\$params));

# check connection
    unless (defined $self->{'connection'}) {
	log_it('debug', __PACKAGE__  . "::_request: connection to DB is dead. Try to restore.");
	unless($self->_connect()) {
	    return { 'error' => $DBI::errstr, 'data' => [] };
	}
	else {
	    log_it('debug', __PACKAGE__ . "::_request: connection to DB restored.");
	}
    }

# prepare request if need to
    unless ($self->{'requests'}->{$request}) {
	$self->{'requests'}->{$request} = $self->{'connection'}->prepare($request);
	log_it('debug', __PACKAGE__ . "::_request: request '%s' to DB prepared", $request);
    }

    if (!$self->{'requests'}->{$request}) {
	delete $self->{'requests'}->{$request};
# preparation failed - get error message and try failover variant if need to
	$result->{'error'} = $self->{'connection'}->errstr();
	log_it('info', __PACKAGE__ . "::_request: request '%s' preparation to DB failed. Error: %s", $request, $result->{'error'});
	unless ($params->{'_retry'} || $self->{'connection'}->ping()) {
# it was first try and DB connection is dead (ping failed) - retry
	    log_it('debug', __PACKAGE__ . "_request: connection to DB is dead. Try to execute request '%s' once again.", $request);
	    return $self->_retry($result, $params, $request, @args);
	}

	return $result;
    }

# execute request
    log_it('debug', __PACKAGE__ . "::_request: executing request '%s' to DB", $request);
    my $success = $self->{'requests'}->{$request}->execute(@args) ? 1 : 0;
    if ($success) {
	log_it('debug', __PACKAGE__ . "::_request: request '%s' to DB executed successfully", $request);
	$result->{'data'} = [];
	if ($params->{'select'}) {
	    log_it('debug', __PACKAGE__ . "::_request: obtaining data after selective request '%s' to DB", $request);
# for selective request - obtain resulting data and place it into resulting hash
	    while (my $row = $self->{'requests'}->{$request}->fetchrow_hashref()) {
		push(@{$result->{'data'}}, $row);
	    }

	    if ($self->{'requests'}->{$request}->err()) {
# something went wrong while obtaining resulting data - get error message, rollback all changes and try failover variant if need to
		$result->{'error'} = $self->{'requests'}->{$request}->errstr();
		log_it('info', __PACKAGE__ . "::_request: obtaining data after request '%s' to DB failed. Error: %s", $request, $result->{'error'});
		log_it('debug', __PACKAGE__ . "::_request: rolling back all changes made to DB");
		$self->{'connection'}->rollback();

		unless ($params->{'_retry'} || $self->{'connection'}->ping()) {
# it was first try and DB connection is dead (ping failed) - retry
		    log_it('debug', __PACKAGE__ . "::_request: connection to DB is dead. Try to execute request '%s' once again.", $request);
		    return $self->_retry($result, $params, $request, @args);
		}

	    }
	    else {
# everything fine, data from selective result obtained - commit changes to DB
		log_it('debug', __PACKAGE__ . "::_request: commiting data after selective request '%s' to DB", $request);
		$self->{'connection'}->commit();
	    }
	}
	else {
# everything fine, non-selective request succeed - commit changes to DB
	    $result->{'data'} = 1;
	    log_it('debug', __PACKAGE__ . "::_request: commiting data after non-selective request '%s' to DB", $request);
	    $self->{'connection'}->commit();
	}
    }
    else {
# request execution failed - get error message, rollback changes and try failover variant if need to
	$result->{'error'} = $self->{'requests'}->{$request}->errstr();
	log_it('info', __PACKAGE__ . "::_request: execution of request '%s' to DB failed. Error: %s", $request, $result->{'error'});
	log_it('debug', __PACKAGE__ . "::_request: rolling back all changes made to DB");
	$self->{'connection'}->rollback();
	unless ($params->{'_retry'} || $self->{'connection'}->ping()) {
# it was first try and DB connection is dead (ping failed) - retry
	    log_it('debug', __PACKAGE__ . "::_request: connection to DB is dead. Try to execute request '%s' once again.", $request);
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
# Description: retry to perform SQL-request over given DB whose connection was closed
# Argument(s): 1: previous attempt's result (link to hash), 2: request parameters (link to hash), 3: request (string), 4, ...: arguments of request
# Return: previous attempt's result if DB reconnection fails, request result (link to hash) - otherwise
#
# Structure of request parameters' hash: see above in _request method (it's the same)
#
# Structure of request result hash and previous attempt's result: see above in _request method (it's the same)
sub _retry {
    my $self = shift;
    my $old_result = shift;
    my $params = shift;
    my $request = shift;
    my @args = @_;

    log_it('debug', __PACKAGE__ . "::_retry: second try for request: %s, args: %s, params: %s", $request, Dumper(\@args), Dumper(\$params));

    unless ($self->_reconnect()) {
	log_it('debug', __PACKAGE__ . "::_retry: reconnection to DB failed. Second try for request '%s' failed.", $request);

	return $old_result;
    }

    log_it('debug', __PACKAGE__ . "::_retry: reconnection to DB succeed. Launch second try for request '%s'", $request);

    $params->{'_retry'} = 1;
    return $self->_request($params, $request, @args);
}

# Method: _reconnect
# Description: reopen connection to a given DB
# Argument(s): 1: DB name (string)
# Return: 1 on successful reconnection, 0 - otherwise
sub _reconnect {
    my $self = shift;

    log_it('debug', __PACKAGE__ . "::_reconnect: reconnecting to DB");

    return $self->_disconnect() && $self->_connect();
}


# Method: _connect
# Description: open connection to a given DB
# Argument(s): 1: DB name (string)
# Return: 1 on successful connection, 0 - otherwise
sub _connect {
    my $self = shift;

    log_it('debug', __PACKAGE__ . "::_connect: connecting to DB");

    my $result = undef;
    eval {
	unless ( $self->{'connection'} = DBI->connect(
						    'dbi:' . $self->{'config'}->{'driver'} .
						    ':' . $self->{'config'}->{'dsn'},
							  $self->{'config'}->{'user'},
							  $self->{'config'}->{'passwd'},
							  { RaiseError => 0,
							    PrintError => 0,
							    AutoCommit => 0,
							    ChopBlanks => 1
							  } ) ) {
	    log_it('err', __PACKAGE__ . "::_connect: can't connect to DB: %s", $DBI::errstr);
	    $result = 0;
	}
	else {
	    log_it('debug', __PACKAGE__ . "::_connect: successfully connected to DB");
	    $result = 1;
	}
    };

    unless (defined $result) {
	log_it('err', __PACKAGE__ . "::_connect: can't connect to DB: %s", $@);
	$result = 0;
    }

    return $result;
}

# Method: _disconnect
# Description: close given DB connection
# Argument(s): 1: DB name (string)
# Return: 1 on successful disconnection, 0 - otherwise
sub _disconnect {
    my $self = shift;

    log_it('debug', __PACKAGE__ . "::_disconnect: disconnecting from DB");

    if (defined $self->{'connection'}) {
# rollback all uncommited changes
	log_it('debug', __PACKAGE__ . "::_disconnect: rolling back all changes made to DB");
	my $res = $self->{'connection'}->rollback();
	log_it('err', __PACKAGE__ . "::_disconnect: error while rolling back changes: %s", $self->errstr()) unless $res;
    }
    log_it('debug', __PACKAGE__ . "::_disconnect: finishing all requests to DB");
# finish all cached requests for a given DB
    foreach my $req (keys %{$self->{'requests'}}) {
	if (defined $self->{'requests'}->{$req}) {
	    my $res = $self->{'requests'}->{$req}->finish();
	    log_it('err', __PACKAGE__ . "::_disconnect: error while finishing request: %s", $self->errstr()) unless $res; # hope, this works as i thought
	}
	delete $self->{'requests'}->{$req};
    }
# finally close connection
    if (defined $self->{'connection'}) {
	log_it('debug', __PACKAGE__ . "::_disconnect: finally closing connection to DB");
	my $res = $self->{'connection'}->disconnect() ? 1 : 0;
	$self->{'connection'} = undef;
	return $res;
    }
    else {
	log_it('debug', __PACKAGE__ . "::_disconnect: connection to DB is already closed");
	return 1;
    }
}

# Method: DESTROY
# Description: destructor
# Argument(s): none
# Return: none
sub DESTROY {
    my $self = shift;

    log_it('debug', __PACKAGE__ . '::DESTROY: DB object destruction');

# correctly close all DB connections
    $self->_disconnect();
}

1;
