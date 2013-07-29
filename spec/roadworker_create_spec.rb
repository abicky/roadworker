$: << File.expand_path("#{File.dirname __FILE__}/../lib")
$: << File.expand_path("#{File.dirname __FILE__}/../spec")

require 'rubygems'
require 'roadworker'
require 'spec_helper'
require 'fileutils'
require 'logger'

describe Roadworker::Client do
  before(:each) {
    AWS.config({
      :access_key_id => (ENV['TEST_AWS_ACCESS_KEY_ID'] || 'scott'),
      :secret_access_key => (ENV['TEST_AWS_SECRET_ACCESS_KEY'] || 'tiger'),
    })

    routefile(:force => true) { '' }
    @route53 = AWS::Route53.new
  }

  after(:all) do
    routefile(:force => true) { '' }
  end

  context 'empty' do
    it  {
      expect(@route53.hosted_zones.to_a).to be_empty
    }
  end

  context 'Create' do
    context 'HostedZone' do
      it {
        routefile do
<<EOS
hosted_zone "winebarrel.jp" do
end
EOS
        end

        zones = @route53.hosted_zones.to_a
        expect(zones.length).to eq(1)

        zone = zones[0]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(2)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)
      }
    end

    context 'A record' do
      it {
        routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    ttl 123
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end
end
EOS
        end

        zones = @route53.hosted_zones.to_a
        expect(zones.length).to eq(1)

        zone = zones[0]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(3)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        a = zone.rrsets['www.winebarrel.jp.', 'A']
        expect(a.name).to eq("www.winebarrel.jp.")
        expect(a.ttl).to eq(123)
        expect(rrs_list(a.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])
      }
    end

    context 'A(Alias) record' do
      it {
        routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    dns_name "roadworker-1957159880.ap-northeast-1.elb.amazonaws.com"
  end
end
EOS
        end

        zones = @route53.hosted_zones.to_a
        expect(zones.length).to eq(1)

        zone = zones[0]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(3)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        a = zone.rrsets['www.winebarrel.jp.', 'A']
        expect(a.name).to eq("www.winebarrel.jp.")
        expect(a.alias_target).to eq({
          :hosted_zone_id => "Z2YN17T5R711GT",
          :dns_name => "roadworker-1957159880.ap-northeast-1.elb.amazonaws.com.",
          :evaluate_target_health => false,
        })
      }
    end

    context 'A1 A2' do
      it {
        routefile do
<<-EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "A" do
    set_identifier "web server 1"
    weight 100
    ttl 456
    resource_records(
      "127.0.0.1",
      "127.0.0.2"
    )
  end

  rrset "www.winebarrel.jp", "A" do
    set_identifier "web server 2"
    weight 50
    ttl 456
    resource_records(
      "127.0.0.3",
      "127.0.0.4"
    )
  end
end
EOS
        end

        zones = @route53.hosted_zones.to_a
        expect(zones.length).to eq(1)

        zone = zones[0]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(4)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        a1 = zone.rrsets['www.winebarrel.jp.', 'A', "web server 1"]
        expect(a1.name).to eq("www.winebarrel.jp.")
        expect(a1.set_identifier).to eq('web server 1')
        expect(a1.weight).to eq(100)
        expect(a1.ttl).to eq(456)
        expect(rrs_list(a1.resource_records)).to eq(["127.0.0.1", "127.0.0.2"])

        a2 = zone.rrsets['www.winebarrel.jp.', 'A', "web server 2"]
        expect(a2.name).to eq("www.winebarrel.jp.")
        expect(a2.set_identifier).to eq('web server 2')
        expect(a2.weight).to eq(50)
        expect(a2.ttl).to eq(456)
        expect(rrs_list(a2.resource_records)).to eq(["127.0.0.3", "127.0.0.4"])
      }
    end

    context 'TXT record' do
      it {
        routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "TXT" do
    ttl 123
    resource_records(
      '"v=spf1 +ip4:192.168.100.0/24 ~all"',
      '"spf2.0/pra +ip4:192.168.100.0/24 ~all"',
      '"spf2.0/mfrom +ip4:192.168.100.0/24 ~all"'
    )
  end
end
EOS
        end

        zones = @route53.hosted_zones.to_a
        expect(zones.length).to eq(1)

        zone = zones[0]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(3)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        txt = zone.rrsets['www.winebarrel.jp.', 'TXT']
        expect(txt.name).to eq("www.winebarrel.jp.")
        expect(txt.ttl).to eq(123)
        expect(rrs_list(txt.resource_records)).to eq([
          "\"spf2.0/mfrom +ip4:192.168.100.0/24 ~all\"",
          "\"spf2.0/pra +ip4:192.168.100.0/24 ~all\"",
          "\"v=spf1 +ip4:192.168.100.0/24 ~all\""
        ])
      }
    end

    context 'CNAME record' do
      it {
        routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "CNAME" do
    ttl 123
    resource_records("www2.winebarrel.jp")
  end
end
EOS
        end

        zones = @route53.hosted_zones.to_a
        expect(zones.length).to eq(1)

        zone = zones[0]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(3)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        cname = zone.rrsets['www.winebarrel.jp.', 'CNAME']
        expect(cname.name).to eq("www.winebarrel.jp.")
        expect(cname.ttl).to eq(123)
        expect(rrs_list(cname.resource_records)).to eq(["www2.winebarrel.jp"])
      }
    end

    context 'MX record' do
      it {
        routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "MX" do
    ttl 123
    resource_records(
      "10 mail.winebarrel.jp",
      "20 mail2.winebarrel.jp"
    )
  end
end
EOS
        end

        zones = @route53.hosted_zones.to_a
        expect(zones.length).to eq(1)

        zone = zones[0]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(3)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        mx = zone.rrsets['www.winebarrel.jp.', 'MX']
        expect(mx.name).to eq("www.winebarrel.jp.")
        expect(mx.ttl).to eq(123)
        expect(rrs_list(mx.resource_records)).to eq(["10 mail.winebarrel.jp", "20 mail2.winebarrel.jp"])
      }
    end

    context 'PTR record' do
      it {
        routefile do
<<EOS
hosted_zone "333.222.111.in-addr.arpa" do
  rrset "444.333.222.111.in-addr.arpa", "PTR" do
    ttl 123
    resource_records("www.winebarrel.jp")
  end
end
EOS
        end

        zones = @route53.hosted_zones.to_a
        expect(zones.length).to eq(1)

        zone = zones[0]
        expect(zone.name).to eq("333.222.111.in-addr.arpa.")
        expect(zone.resource_record_set_count).to eq(3)

        expect(zone.rrsets['333.222.111.in-addr.arpa.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['333.222.111.in-addr.arpa.', 'SOA'].ttl).to eq(900)

        ptr = zone.rrsets['444.333.222.111.in-addr.arpa.', 'PTR']
        expect(ptr.name).to eq("444.333.222.111.in-addr.arpa.")
        expect(ptr.ttl).to eq(123)
        expect(rrs_list(ptr.resource_records)).to eq(["www.winebarrel.jp"])
      }
    end

    context 'SRV record' do
      it {
        routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "ftp.winebarrel.jp", "SRV" do
    ttl 123
    resource_records(
      "1   0   21  server01.example.jp",
      "2   0   21  server02.example.jp"
    )
  end
end
EOS
        end

        zones = @route53.hosted_zones.to_a
        expect(zones.length).to eq(1)

        zone = zones[0]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(3)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        srv = zone.rrsets['ftp.winebarrel.jp.', 'SRV']
        expect(srv.name).to eq("ftp.winebarrel.jp.")
        expect(srv.ttl).to eq(123)
        expect(rrs_list(srv.resource_records)).to eq([
          "1   0   21  server01.example.jp",
          "2   0   21  server02.example.jp"
        ])
      }
    end

    context 'AAAA record' do
      it {
        routefile do
<<EOS
hosted_zone "winebarrel.jp" do
  rrset "www.winebarrel.jp", "AAAA" do
    ttl 123
    resource_records("::1")
  end
end
EOS
        end

        zones = @route53.hosted_zones.to_a
        expect(zones.length).to eq(1)

        zone = zones[0]
        expect(zone.name).to eq("winebarrel.jp.")
        expect(zone.resource_record_set_count).to eq(3)

        expect(zone.rrsets['winebarrel.jp.', 'NS'].ttl).to eq(172800)
        expect(zone.rrsets['winebarrel.jp.', 'SOA'].ttl).to eq(900)

        aaaa = zone.rrsets['www.winebarrel.jp.', 'AAAA']
        expect(aaaa.name).to eq("www.winebarrel.jp.")
        expect(aaaa.ttl).to eq(123)
        expect(rrs_list(aaaa.resource_records)).to eq(["::1"])
      }
    end
  end
end