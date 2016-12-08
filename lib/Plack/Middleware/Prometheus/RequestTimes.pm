use strict;
use warnings;
package Plack::Middleware::Prometheus::RequestTimes;

use parent qw( Plack::Middleware );
use Plack::Util::Accessor qw( observer );
use Time::HiRes;

our $VERSION = '0.0001';

sub call {
    my $self = shift;
    my($env) = @_;

	my $start = [ Time::HiRes::gettimeofday ];
    my $res = $self->app->($env);
    if ( ref($res) && ref($res) eq 'ARRAY' ) {
        my $req_time = sprintf '%.6f', Time::HiRes::tv_interval($start);
		$self->observer->observe($req_time);
        return $res;
    }

    return $self->response_cb($res, sub {
        my $res = shift;
        my $req_time = sprintf '%.6f', Time::HiRes::tv_interval($start);
		$self->observer->observe($req_time);
    });
}



1;

# ABSTRACT: record response times with a prometheus histogram.

=head1 DESCRIPTION

To setup a prometheus metrics app in your PSGI application register
hook this middleware up with a histogram and the metrics can report
on your response times.

	use strict;
	use warnings;
	use My::Website;
	use Net::Prometheus;
	use Net::Prometheus::ProcessCollector;

	my $client = Net::Prometheus->new;

	$client->register( Net::Prometheus::ProcessCollector->new(
	   prefix => "parent_process",
	   pid => getppid(),
	) );
	my $response_times = $client->new_histogram(
		name => "response_times",
		help => "Application response times",
	);

	use Plack::Builder;

	my $app = My::Website->apply_default_middlewares(My::Website->psgi_app);

	builder {
		mount "/metrics" => $client->psgi_app;
		mount '/' => builder {
			enable 'Prometheus::RequestTimes', observer => $response_times;
			$app;
		};
	};


=head1 CONFIGURATION

=head2 observer

Normally a L<Net::Prometheus::Histogram> object for recording the observations.

=cut
