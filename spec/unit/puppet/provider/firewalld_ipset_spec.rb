require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_ipset).provider(:firewall_cmd)

describe provider_class do
  let(:resource) do
    @resource = Puppet::Type.type(:firewalld_ipset).new(
      ensure: :present,
      name: 'white',
      type: 'hash:net',
      entries: ['8.8.8.8'],
      provider: described_class.name
    )
  end
  let(:provider) { resource.provider }
  before :each do
    provider.class.stubs(:execute_firewall_cmd).with(['--get-ipsets'], nil).returns('white black')
    provider.class.stubs(:execute_firewall_cmd).with(['--state'], nil, false, false, false).returns(Object.any_instance.stubs(exitstatus: 0))
    provider.class.stubs(:execute_firewall_cmd).with(['--info-ipset=white'], nil).returns('white
  type: hash:ip
  options: maxelem=200 family=inet6
  entries:')
    provider.class.stubs(:execute_firewall_cmd).with(['--info-ipset=black'], nil).returns('black
  type: hash:ip
  options: maxelem=400 family=inet hashsize=2048
  entries:')
    provider.class.stubs(:execute_firewall_cmd).with(['--ipset=white', '--get-entries'], nil).returns('')
    tempfile = stub('tempfile', :class => Tempfile,
                :write => true,
                :flush => true,
                :close! => true,
                :close => true,
                :path => '/tmp/ipset-rspec'
               )
    Tempfile.stubs(:new).returns(tempfile)
  end

  describe 'self.instances' do
    it 'returns an array of ip sets' do
      ipsets_names = provider.class.instances.collect(&:name)
      expect(ipsets_names).to include('black', 'white')
      ipsets_families = provider.class.instances.collect(&:family)
      expect(ipsets_families).to include('inet', 'inet6')
      ipsets_hashsize = provider.class.instances.collect(&:hashsize)
      expect(ipsets_hashsize).to include('2048')
      ipsets_maxelem = provider.class.instances.collect(&:maxelem)
      expect(ipsets_maxelem).to include('200', '400')
    end
  end

  describe 'when creating' do
    context 'basic ipset' do
      it 'should create a new ipset with entries' do
        resource.expects(:[]).with(:name).returns('white').at_least_once
        resource.expects(:[]).with(:type).returns('hash:net').at_least_once
        resource.expects(:[]).with(:family).returns('inet').at_least_once
        resource.expects(:[]).with(:hashsize).returns(1024).at_least_once
        resource.expects(:[]).with(:maxelem).returns(65_536).at_least_once
        resource.expects(:[]).with(:timeout).returns(nil).at_least_once
        resource.expects(:[]).with(:options).returns({}).at_least_once
        resource.expects(:[]).with(:manage_entries).returns(true)
        resource.expects(:[]).with(:entries).returns(['192.168.0/24', '10.0.0/8'])
        provider.expects(:execute_firewall_cmd).with(['--new-ipset=white', '--type=hash:net', '--option=family=inet', '--option=hashsize=1024', '--option=maxelem=65536'], nil)
        provider.expects(:execute_firewall_cmd).with(["--ipset=white", "--add-entries-from-file=/tmp/ipset-rspec"], nil)
        provider.create
      end
    end
  end

  describe 'when modifying' do
    context 'hashsize' do
      it 'should remove and create a new ipset' do
        resource.expects(:[]).with(:name).returns('white').at_least_once
        resource.expects(:[]).with(:type).returns('hash:net').at_least_once
        resource.expects(:[]).with(:family).returns('inet').at_least_once
        resource.expects(:[]).with(:hashsize).returns(nil)
        resource.expects(:[]).with(:hashsize).returns(2048)
        resource.expects(:[]).with(:maxelem).returns(nil).at_least_once
        resource.expects(:[]).with(:timeout).returns(nil).at_least_once
        resource.expects(:[]).with(:options).returns({}).at_least_once
        resource.expects(:[]).with(:manage_entries).returns(true).at_least_once
        resource.expects(:[]).with(:entries).returns(['192.168.0/24', '10.0.0/8']).at_least_once
        provider.expects(:execute_firewall_cmd).with(['--new-ipset=white', '--type=hash:net', '--option=family=inet'], nil)
        provider.expects(:execute_firewall_cmd).with(['--new-ipset=white', '--type=hash:net', '--option=family=inet', '--option=hashsize=2048'], nil)
        provider.expects(:execute_firewall_cmd).with(['--delete-ipset=white'], nil)
        provider.expects(:execute_firewall_cmd).with(["--ipset=white", "--add-entries-from-file=/tmp/ipset-rspec"], nil).at_least_once
        provider.create
        provider.hashsize = 2048
      end
    end
    context 'entries' do
      it 'should remove and add entries' do
        resource.expects(:[]).with(:name).returns('white').at_least_once
        resource.expects(:[]).with(:type).returns('hash:net').at_least_once
        resource.expects(:[]).with(:family).returns('inet').at_least_once
        resource.expects(:[]).with(:hashsize).returns(nil)
        resource.expects(:[]).with(:maxelem).returns(nil).at_least_once
        resource.expects(:[]).with(:timeout).returns(nil).at_least_once
        resource.expects(:[]).with(:options).returns({}).at_least_once
        resource.expects(:[]).with(:manage_entries).returns(true).at_least_once
        resource.expects(:[]).with(:entries).returns(['192.168.0.0/24', '10.0.0.0/8']).at_least_once
        provider.expects(:entries).returns(['192.168.0.0/24', '10.0.0.0/8']).at_least_once
        provider.expects(:execute_firewall_cmd).with(['--new-ipset=white', '--type=hash:net', '--option=family=inet'], nil)
        provider.expects(:execute_firewall_cmd).with(["--ipset=white", "--add-entries-from-file=/tmp/ipset-rspec"], nil).at_least_once
        provider.expects(:execute_firewall_cmd).with(["--ipset=white", "--remove-entries-from-file=/tmp/ipset-rspec"], nil).at_least_once

        provider.create
        provider.entries = ['192.168.14.0/24', '10.0.0.0/8']
      end
      it 'should ignore entries when manage_entries is false ' do
        resource.expects(:[]).with(:name).returns('white').at_least_once
        resource.expects(:[]).with(:type).returns('hash:net').at_least_once
        resource.expects(:[]).with(:family).returns('inet').at_least_once
        resource.expects(:[]).with(:hashsize).returns(nil)
        resource.expects(:[]).with(:maxelem).returns(nil).at_least_once
        resource.expects(:[]).with(:timeout).returns(nil).at_least_once
        resource.expects(:[]).with(:options).returns({}).at_least_once
        resource.expects(:[]).with(:manage_entries).returns(false).at_least_once
        provider.expects(:execute_firewall_cmd).with(['--new-ipset=white', '--type=hash:net', '--option=family=inet'], nil)
        provider.create
        provider.entries = ['192.168.14.0/24', '10.0.0.0/8']
      end

    end
  end
end
