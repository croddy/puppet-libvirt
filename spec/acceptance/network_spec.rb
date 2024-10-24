require 'spec_helper_acceptance'

describe 'libvirt::network' do
  network_dir = '/etc/libvirt/qemu/networks'

  context 'enable default network' do
    it 'enables the default network' do
      pp = <<-EOS
         class { 'libvirt':
           defaultnetwork => true
         }
      EOS

      # Run it twice and test for idempotency
      expect(apply_manifest(pp).exit_code).not_to eq(1)
      expect(apply_manifest(pp).exit_code).to eq(0)
    end

    it 'respond to ping on IP 192.168.122.1 (for interface virbr0)' do
      shell('ping -c1 -q -I virbr0 192.168.122.1') do |r|
        r.exit_code.should == 0
      end
    end
  end

  context 'network directly connected via bridge' do
    it 'creates a network directly connected via a bridge' do
      pp = <<-EOS
         class { 'libvirt': }
         libvirt::network { 'direct-net':
           forward_mode       => 'bridge',
           forward_dev        => 'eth0',
           forward_interfaces => [ 'eth0']
         }
      EOS

      # Run it twice and test for idempotency
      expect(apply_manifest(pp).exit_code).not_to eq(1)
      expect(apply_manifest(pp).exit_code).to eq(0)
    end

    describe file("#{network_dir}/direct-net.xml") do
      it { is_expected.to contain "<forward dev='eth0' mode='bridge'>" }
      it { is_expected.to contain "<interface dev='eth0'/>" }
    end
  end

  context 'network directly connected via autostarted bridge' do
    it 'creates an autostarted network directly connected via a bridge' do
      pp = <<-EOS
         class { 'libvirt': }
         libvirt::network { 'direct-net':
           autostart          => true,
           forward_mode       => 'bridge',
           forward_dev        => 'eth0',
           forward_interfaces => [ 'eth0']
         }
      EOS

      # Run it twice and test for idempotency
      expect(apply_manifest(pp).exit_code).not_to eq(1)
      expect(apply_manifest(pp).exit_code).to eq(0)
    end

    it 'respond to ping on public IPs (for interface eth0)' do
      shell('ping -c1 -q -I eth0 8.8.8.8') do |r|
        r.exit_code.should == 0
      end
    end
  end

  context 'autostarted pxe boot via dhcp' do
    it 'creates an autostarted network for booting from DHCP' do
      pp = <<-EOS
         class { 'libvirt': }
         $dhcp = {
           'start' => '192.168.122.2',
           'end'   => '192.168.122.254',
           'bootp_file' => 'pxelinux.0',
         }
         $ip = {
           'address' => '192.168.122.1',
           'netmask' => '255.255.255.0',
           'dhcp'    => $dhcp,
         }
         libvirt::network { 'pxe':
           autostart    => true,
           ensure       => 'running',
           forward_mode => 'nat',
           forward_dev  => 'virbr0',
           bridge       => 'virbr0',
           ip           => [ $ip]
         }
      EOS

      # Run it twice and test for idempotency
      expect(apply_manifest(pp).exit_code).not_to eq(1)
      expect(apply_manifest(pp).exit_code).to eq(0)
    end

    it 'respond to ping on IP 192.168.122.1 (for interface virbr0)' do
      shell('ping -c1 -q -I virbr0 192.168.122.1') do |r|
        r.exit_code.should == 0
      end
    end
  end

  context 'autostarted dual-stack' do
    it 'creates an autostarted network with NATed IPv4 network and an IPv6 address' do
      pp = <<-EOS
         class { 'libvirt': }
         $dhcp = {
           'start' => '192.168.222.2',
           'end'   => '192.168.222.254',
         }
         $ip = {
           'address' => '192.168.222.1',
           'netmask' => '255.255.255.0',
         }
         $ipv6 = {
           address => '2001:db8:ca2:2::1',
           prefix  => '64',
         }
         libvirt::network { 'dual-stack':
           autostart    => true,
           ensure       => 'running',
           forward_mode => 'nat',
           forward_dev  => 'virbr2',
           bridge       => 'virbr2',
           ip           => [ $ip],
           ipv6         => [ $ipv6 ],
         }
      EOS

      # Run it twice and test for idempotency
      expect(apply_manifest(pp).exit_code).not_to eq(1)
      expect(apply_manifest(pp).exit_code).to eq(0)
    end

    it 'respond to ping on IP 192.168.222.1 (for interface virbr2)' do
      shell('ping -c1 -q -I virbr2 192.168.222.1') do |r|
        r.exit_code.should == 0
      end
    end

    it 'respond to ping6 on IP 2001:db8:ca2:2::1 (for interface virbr2)' do
      shell('ping6 -c1 -q -I virbr2 2001:db8:ca2:2::1') do |r|
        r.exit_code.should == 0
      end
    end
  end
end
