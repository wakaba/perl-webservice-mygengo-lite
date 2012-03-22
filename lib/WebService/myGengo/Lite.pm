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

our $APIVersion = '1.1';

sub base_url {
    my $self = shift;
    if ($self->is_production) {
        return qq<http://api.mygengo.com/v$APIVersion/>;
    } else {
        return qq<http://api.sandbox.mygengo.com/v$APIVersion/>;
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
        %$data, ## for GET
        api_key => $self->api_key,
        data => perl2json_bytes($data), ## for POST
        ts => $time,
    };
    my $qs = join '&', map {
        (percent_encode_c $_ ) . '=' . (percent_encode_c $params->{$_});
    } sort { $a cmp $b } keys %$params;
    if ($APIVersion eq '1') {
      ## Does not work for POST...
      $qs .= '&api_sig=' . hmac_sha1_hex $qs, $self->private_key;
    } else { # 1.1
      $qs .= '&api_sig=' . hmac_sha1_hex $time, $self->private_key;
    }

    if ($args{method} and $args{method} eq 'POST') {
        my ($req, $res) = http_post_data
            url => $self->base_url . $args{path},
            header_fields => {
                'Accept' => 'application/json',
                'Content-Type' => 'application/x-www-form-urlencoded',
            },
            content => $qs;
        return WebService::myGengo::Lite::Response->new_from_lwp_res(
            $res,
            job_data_key => $args{job_data_key},
            input_jobs => $args{input_jobs},
        );
    } else {
        my ($req, $res) = http_get
            url => $self->base_url . $args{path} . q<?> . $qs,
            header_fields => {
                'Accept' => 'application/json',
            };
        return WebService::myGengo::Lite::Response->new_from_lwp_res(
            $res,
            job_data_key => $args{job_data_key},
            input_jobs => $args{input_jobs},
        );
    }
}

## <http://mygengo.com/api/developer-docs/methods/translate-service-languages-get/>.
#
# $res->data = [{lc => langtag, language => ..., localized_name => ...,
#                unit_type => ...}]
sub service_langs {
    my ($self, %args) = @_;
    return $self->request(
        path => q<translate/service/languages>,
    );
}

## <http://mygengo.com/api/developer-docs/methods/translate-service-language-pairs-get/>.
#
# $res->data = [{lc_src => langtag, lc_tgt => langtag,
#                unit_price => ..., tier => ...}]
sub service_lang_pairs {
    my ($self, %args) = @_;
    return $self->request(
        path => q<translate/service/language_pairs>,
        data => {
            lc_src => $args{source_lang},
        },
    );
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

## <http://mygengo.com/api/developer-docs/methods/translate-jobs-post/>.
sub job_post {
  my ($self, $jobs, %args) = @_;
  return $self->request
      (method => 'POST',
       path => q<translate/jobs>,
       data => {
         jobs => [map { $_->as_jsonable } @$jobs],
         as_group => $args{as_group} || 0,
       });
} # job_post

## <http://mygengo.com/api/developer-docs/methods/translate-jobs-get/>.
sub job_list {
  my ($self, %args) = @_;
  return $self->request
      (method => 'GET',
       path => q<translate/jobs>,
       data => {
         status => $args{status},
         timestamp_after => $args{timestamp_after},
         count => $args{count},
       });
} # job_list

## <http://mygengo.com/api/developer-docs/methods/translate-job-id-get/>.
sub job_get ($$%) {
  my ($self, $job_id, %args) = @_;
  return $self->request
      (method => 'GET',
       path => q<translate/job/> . $job_id,
       data => {
         pre_mt => $args{pre_mt} || 0,
       });
}

## <http://mygengo.com/api/developer-docs/methods/translate-jobs-ids-get/>.
sub jobs_get ($$%) {
  my ($self, $job_ids, %args) = @_;
  return $self->request
      (method => 'GET',
       path => q<translate/jobs/> . join ',', @$job_ids);
}

## <http://mygengo.com/api/developer-docs/methods/translate-service-quote-post/>.
sub quote {
    my ($self, $jobs, %args) = @_;
    return $self->request
        (method => 'POST',
         path => q<translate/service/quote>,
         data => {
             jobs => [map { $_->as_jsonable } @$jobs],
         },
         job_data_key => 'quote',
         input_jobs => $jobs);
    # {jobs => [{eta => ..., credits => ..., unit_count => ...}]}
} # quote

## <http://mygengo.com/api/developer-docs/methods/translate-job-id-preview-get/>.
sub job_preview ($$%) {
    my ($self, $job_id, %args) = @_;
    return $self->request
        (method => 'GET',
         path => q<translate/job/> . $job_id . q</preview>);
}

package WebService::myGengo::Lite::Job;

## <http://mygengo.com/api/developer-docs/payloads/>.

sub new_from_json_job {
    my ($class, $job) = @_;
    
    $job->{source}->{body} = delete $job->{body_src};
    $job->{source}->{lang} = delete $job->{lc_src};
    
    $job->{target}->{lang} = delete $job->{lc_tgt};
    $job->{target}->{preview_image_url} = delete $job->{preview_url};
    
    $job->{quote}->{unit_count} = delete $job->{unit_count};
    $job->{quote}->{eta} = delete $job->{eta};
    $job->{quote}->{credits} = delete $job->{credits};
    
    return bless $job, $class;
}

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
use MIME::Base64;

sub new_from_lwp_res ($$;%) {
    my ($class, $res, %args) = @_;

    my $result = {};
    
    if ($res->is_success) {
        my $ct = $res->content_type;
        if ($ct =~ m{application/json}) {
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
        } elsif ($ct =~ m{image/jpeg}) {
            $result->{jpeg_data} = $res->content;
        } else {
            $result->{is_error} = 1;
            $result->{error_message} = 'Unsupported MIME type';
            $result->{error_details} = $ct;
        }
    } else {
        $result->{is_error} = 1;
        $result->{error_message} = $res->status_line;
        $result->{error_details} = $res->content;
    }

    if (not $result->{is_error} and
        $args{job_data_key} and
        $args{input_jobs} and
        $result->{data} and ref $result->{data} eq 'HASH' and
        $result->{data}->{jobs} and ref $result->{data}->{jobs} eq 'ARRAY') {
        for (0..$#{$args{input_jobs}}) {
            $args{input_jobs}->[$_]->{$args{job_data_key}} = $result->{data}->{jobs}->[$_];
        }
        $result->{jobs} = $args{input_jobs};
    } elsif ($result->{data} and ref $result->{data} eq 'HASH' and
             $result->{data}->{jobs} and
             ref $result->{data}->{jobs} eq 'ARRAY') {
        $result->{jobs} = [map { WebService::myGengo::Lite::Job->new_from_json_job($_) } @{$result->{data}->{jobs}}];
    } elsif ($result->{data} and ref $result->{data} eq 'HASH' and
             $result->{data}->{job} and ref $result->{data}->{job} eq 'HASH') {
        $result->{jobs} = [WebService::myGengo::Lite::Job->new_from_json_job($result->{data}->{job})];
    }
    
    return bless $result, $class;
}

sub data {
    return $_[0]->{data};
}

sub jobs {
    return $_[0]->{jobs};
}

sub image_as_data_url {
    my $self = shift;
    if ($self->{jpeg_data}) {
        my $mime = encode_base64 $self->{jpeg_data};
        $mime =~ s/\s+//g;
        return 'data:image/jpeg;base64,' . $mime;
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

