# CREATE TABLE links (
#     id BIGINT PRIMARY KEY
#       -- no uper bound constraint since BIGINT is int64_t and we have a 63-bit range
#       CONSTRAINT links_id_naturalnumber_chk CHECK (id >= 0),
#     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
#     request JSONB NOT NULL,
#     target VARCHAR NOT NULL
#       CONSTRAINT links_target_urlish_chk CHECK (target ~* '^https?://[0-9a-z]')
# );
#
# -- lower case
# INSERT INTO links (id, created_at, request, target) VALUES (0, '-infinity', 'null', 'http://example.com');
# -- title case
# INSERT INTO links (id, created_at, request, target) VALUES (4760464235854074888, '-infinity',  'null', 'http://example.com');
# -- upper case
# INSERT INTO links (id, created_at, request,target) VALUES (9223372036854775807, '-infinity',  'null', 'http://example.com');
# -- mine: 'LoREMIpSumDolorSItAmETCoNsecTeTURADIpiscinGEliTSeDDOEIUsmOdTeMp'
# INSERT INTO links (id, created_at, request,target) VALUES (6669925906114002722, '-infinity',  'null', 'http://example.com');
#
# CREATE TABLE clicks (
#     id BIGINT NOT NULL
#       CONSTRAINT clicks_id_naturalnumber_chk CHECK (id >= 0),
#     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
#     request JSONB NOT NULL
# );

require 'sinatra'
require 'pg'

DOMAIN = 'LoremIpsumDolorSitAmetConsecteturAdipiscingElitSedDoEiusmodTemp'.downcase.freeze
MASK = (2**DOMAIN.length-1).freeze

class String
    def get_case
        result = 0
        self.each_char do |c|
            result <<= 1
            result += 1 if ('A'..'Z').include? c
        end
        result
    end
    def set_case(case_int)
        pos = -1
        while case_int > 0 do
            self[pos] = self[pos].upcase if case_int.odd?
            case_int >>= 1
            pos -= 1
        end
        self
    end
end

get '/' do
    domain = request.host.split('.').first
    halt 400 unless domain.downcase == DOMAIN
    id = domain.get_case

    db_uri = URI.parse(ENV['DATABASE_URL'])
    conn = PG.connect(db_uri.hostname, db_uri.port, nil, nil, db_uri.path[1..-1], db_uri.user, db_uri.password)

    conn.exec_params('INSERT INTO clicks (id, request) VALUES ($1, $2)', [id, request.env.to_json])
    result = conn.exec_params(%q(SELECT target FROM links WHERE id = $1 AND created_at > '-infinity'), [id]).values.first

    unless result.nil?
        redirect result.first
    end

    haml :home, :format => :html5
end

post '/' do
    target = request.params['target']
    begin
        uri = URI(target)
        %w(http https).include? uri.scheme or raise "bad scheme"
        uri.host or raise "bad host"
    rescue
        halt 400
    end

    id = SecureRandom.random_bytes(8).unpack('Q').first & MASK
    db_uri = URI.parse(ENV['DATABASE_URL'])
    conn = PG.connect(db_uri.hostname, db_uri.port, nil, nil, db_uri.path[1..-1], db_uri.user, db_uri.password)
    begin
        conn.exec_params('INSERT INTO links (id, request, target) VALUES ($1, $2, $3)', [id, request.env.to_json, target])
    rescue
        # either I screwed up or there's a super-unlikely id collision
        halt 500
    end

    url = "http://#{DOMAIN.dup.set_case(id)}.com"
    content_type :json
    { :url => url }.to_json
end
