package SU::API::Aptly;

use strict;
use warnings;

use HTTP::Request;
use JSON;
use LWP::UserAgent;
use URI::Escape;
use Encode qw( encode_utf8 );

sub new {
    my ($class, %args) = @_;
    my $self = {
        hostname => $args{hostname},
        port => $args{port},
        ssl => $args{ssl},
        timeout => $args{timeout},
    };

    if (! $self->{hostname}) {
        $self->{hostname} = "localhost";
    }

    my $protocol = "http";

    if ($self->{ssl}) {
        $protocol = "https";
    }

    if (! $self->{port}) {
        if ($protocol eq "http") {
            $self->{port} = "80";
        } else {
            $self->{port} = "443";
        }
    }

    $self->{ua} = LWP::UserAgent->new;
    $self->{ua}->default_header('Accept' => 'application/json');
    if ($self->{timeout}) {
        $self->{ua}->timeout($self->{timeout});
    }

    $self->{url} = "$protocol://$self->{hostname}:$self->{port}/api";
    $self->{login_status} = "Not logged in.";

    bless $self, $class;
    return $self;
};

sub do_request {
    my ($self, %args) = @_;
    my $method = $args{method};
    my $uri = $args{uri};
    my $data = $args{data};
    my $params = $args{params};
    my $plaintext = $args{plaintext};

    if (! $method) {
        print "Method missing.";
        return undef;
    } elsif (! $uri) {
        print "URI missing.";
        return undef;
    }

    my $request_url;
    $request_url = "$self->{url}${uri}";

    my $content_type;

    if ($method eq "POST" or $method eq "PUT"){
        if ($data) {
           $data = encode_json($data);
        }
        $content_type = "application/json";
    } else {
        $content_type = "application/x-www-form-urlencoded";
    }
    if ($params) {
        $params = encode_params($params);
        $request_url = "$self->{url}${uri}?$params";
    };

    my $req = HTTP::Request->new($method => $request_url);
    $req->content_type($content_type);
    $req->content($data);

    $self->{res} = $self->{ua}->request($req);
    if (! $self->{res}->is_success) {
        return undef;
    };

    # Just return response as plaintext if plaintext is set.
    if ($plaintext) {
        my $str = encode_utf8($self->{res}->content);
        if($str) {
            return $str;
        }
    }

    my $json_result = decode_json(encode_utf8($self->{res}->content));
    if ($json_result) {
        return $json_result;
    };
    return undef;
};

sub encode_params {
    my $filter = $_[0];
    my @filter_array;
    my @encoded_uri_array;

    if($filter =~ /&/) {
        @filter_array = split('&',$filter);
    } else {
        @filter_array = $filter;
    };
    for(@filter_array) {
        if($_ =~ /=/) {
            my ($argument,$value) = split("=",$_);
            push(@encoded_uri_array,join("=",uri_escape($argument),uri_escape($value)));
        } else {
            push(@encoded_uri_array,uri_escape($_));
        };
    };
    return join("&",@encoded_uri_array);
};

sub login {

    my ($self, $username, $password) = @_;

    if ($username && $password) {

        $self->{username} = $username;
        $self->{password} = $password;

        $self->{ua}->credentials("$self->{hostname}:$self->{port}", "Aptly", $self->{username}, $self->{password});
    }

    $self->do_request(method => "GET", uri => "/version");

    if ($self->request_code == 200 ) {
        $self->{login_status} = "Login successful.";
        $self->{logged_in} = 1;
    } elsif ($self->request_code == 401) {
        $self->{login_status} = "Wrong username/password.";
    } else {
        $self->{login_status} = "Unknown status line: " . $self->{res}->status_line;
    }

    return $self->{logged_in};
};

sub logged_in {
    my ($self) = @_;
    return $self->{logged_in};
};

sub login_status {
    my ($self) = @_;
    return $self->{login_status};
};

sub request_status_line {
    my ($self) = @_;
    return $self->{res}->status_line;
};

sub request_code {
    my ($self) = @_;
    return $self->{res}->code;
};

1;
