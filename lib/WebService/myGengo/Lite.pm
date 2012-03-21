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

package WebService::myGengo::Lite::Response;
use JSON::Functions::XS qw(json_bytes2perl);

sub new_from_lwp_res {
    my ($class, $res) = @_;

    my $result = {};
    
    if ($res->is_success) {
        my $json = json_bytes2perl $res->content;
        if (ref $json eq 'HASH') {
            if ($json->{opstat} eq 'ok') {
                if (ref $json->{response} eq 'HASH') {
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

