package WebService::myGengo::Lite;
use strict;
use warnings;
use Digest::SHA qw(hmac_sha1_hex);
use Web::UserAgent::Functions qw(http_get http_post_data);
use JSON::Functions::XS qw(json_bytes2perl perl2json_bytes);
use Encode;
use URL::PercentEncode;

sub new {
    my $class = shift;
    return bless {@_}, $class;
}

sub is_production {
    if (@_ > 1) {
        $_[0]->{is_production} = $_[1];
    }
    return $_[0]->{is_production};
}

sub base_url {
    my $self = shift;
    if ($self->is_production) {
        return q<http://api.mygengo.com/v1.1/>;
    } else {
        return q<http://api.sandbox.mygengo.com/v1.1/>;
    }
}

sub api_key {
    if (@_ > 1) {
        $_[0]->{api_key} = $_[1];
    }
    return $_[0]->{api_key};
}

sub private_key {
    if (@_ > 1) {
        $_[0]->{private_key} = $_[1];
    }
    return $_[0]->{private_key};
}

sub request {
    my ($self, %args) = @_;
    
    my $data = $args{data} || {};
    my $time = time;

    my $params = {
        api_key => $self->api_key,
        data => perl2json_bytes($data),
        ts => $time,
    };
    my $qs = join '&', map {
        (percent_encode_c $_ ) . '=' . (percent_encode_c $params->{$_});
    } sort { $a cmp $b } keys %$params;
    $qs .= '&api_sig=' . hmac_sha1_hex $time, $self->private_key;

    if ($args{method} and $args{method} eq 'POST') {
        my ($req, $res) = http_post_data
            url => $self->base_url . $args{path},
            header_fields => {
                'Accept' => 'application/json',
                'Content-Type' => 'application/x-www-form-urlencoded',
            },
            content => $qs;
        return WebService::myGengo::Lite::Response->new_from_lwp_res($res);
    } else {
        my ($req, $res) = http_get
            url => $self->base_url . $args{path} . q<?> . $qs,
            header_fields => {
                'Accept' => 'application/json',
            };
        return WebService::myGengo::Lite::Response->new_from_lwp_res($res);
    }
}

# $res->data->{credits}
sub account_balance {
    my ($self, %args) = @_;
    return $self->request(
        path => q<account/balance>,
    );
}

# $res->data->{user_since} time_t
# $res->data->{credits_spent}
sub account_stats {
    my ($self, %args) = @_;
    return $self->request(
        path => q<account/stats>,
    );
}

# source => {body => ..., lang => ...},
# target => {lang => ...},
# tier => "machine", "standard", "pro", "ultra",
# force => boolean,
# comment => ...,
# use_preferred => ...,
# callback_url => ...,
# auto_approve => ...,
# custom_data => ...,
sub create_job_request ($%) {
  shift;
  return bless {@_}, 'WebService::myGengo::Lite::Job';
} # create_job_request

## <http://mygengo.com/api/developer-docs/methods/translate-jobs-get/>.
sub jobs_get {
  my ($self, %args) = @_;
  return $self->request
      (method => 'GET',
       path => q<translate/jobs>,
       data => {
         status => $args{status},
         timestamp_after => $args{timestamp_after},
         count => $args{count},
       });
} # jobs_get

## <http://mygengo.com/api/developer-docs/methods/translate-jobs-post/>.
sub jobs_post {
  my ($self, $jobs, %args) = @_;
  return $self->request
      (method => 'POST',
       path => q<translate/jobs>,
       data => {
         jobs => [map { $_->as_jsonable } @$jobs],
         as_group => $args{as_group} || 0,
       });
} # jobs_post

## <http://mygengo.com/api/developer-docs/methods/translate-job-id-get/>.
sub job_get ($$%) {
  my ($self, $job_id, %args) = @_;
  return $self->request
      (method => 'GET',
       path => q<translate/job/> . $job_id,
       data => {
         pre_mt => $args{pre_mt},
       });
}

package WebService::myGengo::Lite::Job;

## <http://mygengo.com/api/developer-docs/payloads/>.

sub as_jsonable ($) {
  my $self = shift;
  my $json = {
    %$self,
    body_src => $self->{source}->{body},
    lc_src => $self->{source}->{lang},
    lc_tgt => $self->{target}->{lang},
  };
  delete $json->{source};
  delete $json->{target};
  return $json;
} # as_jsonable

package WebService::myGengo::Lite::Response;
use JSON::Functions::XS qw(json_bytes2perl);

sub new_from_lwp_res ($$) {
    my ($class, $res) = @_;

    my $result = {};
    
    if ($res->is_success) {
        my $json = json_bytes2perl $res->content;
        if (ref $json eq 'HASH') {
            if ($json->{opstat} eq 'ok') {
                if (ref $json->{response} eq 'HASH' or
                    ref $json->{response} eq 'ARRAY') {
                    $result->{data} = $json->{response};
                } else {
                    $result->{is_error} = 1;
                    $result->{error_message} = 'Unsupported response';
                    $result->{error_details} = $json;
                }
            } else {
                $result->{is_error} = 1;
                $result->{error_message} = $json->{opstat};
                $result->{error_details} = $json;
            }
        } else {
            $result->{is_error} = 1;
            $result->{error_message} = 'Unsupported response';
            $result->{error_details} = $json;
        }
    } else {
        $result->{is_error} = 1;
        $result->{error_message} = $res->status_line;
        $result->{error_details} = $res->content;
    }
    
    return bless $result, $class;
}

sub data {
    return $_[0]->{data};
}

sub job {
    if ($_[0]->{data} and ref $_[0]->{data} eq 'HASH' and
        $_[0]->{data}->{job} and ref $_[0]->{data}->{job} eq 'HASH') {
        return bless {%{$_[0]->{data}->{job}}}, 'WebService::myGengo::Lite::Job';
    }
    return undef;
}

sub is_error {
    return $_[0]->{is_error};
}

sub error_message {
    return $_[0]->{error_message};
}

sub error_details {
    return $_[0]->{error_details};
}

1;

