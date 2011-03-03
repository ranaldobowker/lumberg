require 'spec_helper'
require 'lumberg/whm'

module Lumberg
  describe Whm::Account do
    before(:each) do
      @login    = { :host => @whm_host, :hash => @whm_hash }
      @server   = Whm::Server.new(@login.dup)
      @account  = Whm::Account.new(:server => @server.dup)
    end

    describe "initialize" do
      it "should create a new instance of server" do
        expect { Whm::Account.new }.to raise_error(WhmArgumentError, /Missing required param/)
      end

      it "should allow a server instance to be passed in" do
        account = Whm::Account.new(:server => @server)
        account.server.should be_a(Whm::Server)
      end

      it "should allow a server hash to be passed in" do
        account = Whm::Account.new(:server => @login)
        account.server.should be_a(Whm::Server)
      end
    end

    describe "create" do
      use_vcr_cassette "whm/account/createacct"

      it "should require a username" do
        expect { @account.create}.to raise_error(WhmArgumentError, /Missing required parameter: username/)
      end

      it "should require a domain" do
        expect { @account.create(:username => 'user')}.to raise_error(WhmArgumentError, /Missing required parameter: domain/)
      end

      it "should require a password" do
        expect { 
          @account.create(:username => 'user', :domain => 'example.com')
        }.to raise_error(WhmArgumentError, /Missing required parameter: password/)
      end

      it "should create the account with proper params" do
        result = @account.create(:username => 'valid', :password => 'hummingbird123', :domain => 'valid-thing.com')
        result[:success].should be_true
        result[:message].should match(/Account Creation Ok/i)
        result[:params].should_not be_empty
        result[:params].should have_key(:options)
        result[:params][:options].should include(:nameserver4, :nameserver, :nameserverentry2, :nameserverentry3, 
                                                  :nameserverentry4, :nameserverentry, :ip, :nameservera2, 
                                                  :nameservera3, :package, :nameservera4, :nameserver2, 
                                                  :nameservera, :nameserver3)
      end

      it "should return an error on duplicate accounts" do
        @account.create(:username => 'invalid', :password => 'hummingbird123', :domain => 'invalid-thing.com')
        result = @account.create(:username => 'invalid', :password => 'hummingbird123', :domain => 'invalid-thing.com')
        result[:success].should be(false)
        result[:message].should match(/username already exists/i)
      end
    end

    describe "remove" do
      use_vcr_cassette "whm/account/removeacct"

      it "should require a 'username' param" do
        expect { @account.remove }.to raise_error(WhmArgumentError, /Missing required parameter: username/)
      end

      it "should remove a user and keep DNS by default" do
        result = @account.remove(:username => 'removeme')
        result[:success].should be_true
        result[:params][:rawout].should match(/Removing DNS Entries/i)
      end

      it "should remove a user and remove DNS when asked" do
        result = @account.remove(:username => 'removeme', :keepdns => false)
        result[:success].should be_true
        result[:params][:rawout].should match(/Removing DNS Entries/i)
      end

      it "should remove a user but keep DNS" do
        result = @account.remove(:username => 'removeme', :keepdns => true)
        result[:success].should be_true
        result[:params][:rawout].should_not match(/Removing DNS Entries/i)
      end

      it "should return an error when the user doesn't exist" do
        result = @account.remove(:username => 'notreal')
        result[:success].should be(false)
        result[:message].should match(/notreal does not exist/i)
      end
    end

    describe "change_password" do
      use_vcr_cassette "whm/account/passwd"

      it "should require a user" do
        expect { @account.change_password }.to raise_error(WhmArgumentError, /Missing required parameter: username/)
      end

      it "should require a password" do
        expect { @account.change_password(:username => 'changeme') }.to raise_error(WhmArgumentError, /Missing required parameter: pass/)
      end

      it "should change the password" do
        result = @account.change_password(:username => 'changeme', :pass => 'superpass')
        result[:success].should be_true
        result[:message].should match(/Password changed for user changeme/i)
      end

      it "should not be successful when the user doesn't exist" do
        result = @account.change_password(:username => 'dontchangeme', :pass => 'superpass')
        result[:success].should be(false)
        result[:message].should match(/dontchangeme does not exist/i)
      end
    end

    describe "limit bandwidth" do
      use_vcr_cassette "whm/account/limitbw"

      it "should require a user" do
        expect { @account.limit_bandwidth(:bwlimit => 99999) }.to raise_error(WhmArgumentError, /Missing required parameter: username/i)
      end

      it "should require a bandwidth" do
        expect { @account.limit_bandwidth(:username => 'changeme') }.to raise_error(WhmArgumentError, /Missing required parameter: bwlimit/i)
      end

      it "should set the bandwidth limit" do
        result = @account.limit_bandwidth(:username => 'changeme', :bwlimit => 99999)
        result[:success].should be_true
        result[:message].should match(/Bandwidth Limit for changeme set to 99999/i)
        result[:params][:bwlimit][:bwlimitenable].should equal(false)
        result[:params][:bwlimit][:unlimited].should equal(true)
      end

      it "should not be successful when the user doesn't exist" do
        expect { 
          @account.limit_bandwidth(:username => 'notexists', :bwlimit => 99999) 
        }.to raise_error(WhmInvalidUser, /User notexists does not exist/i)
      end
    end 

    describe "list_accounts" do
      use_vcr_cassette "whm/account/listaccts"

      it "should list all accounts" do
        result = @account.list_accounts
        result[:success].should be_true
        result[:params][:acct].should have(10).accounts
      end

      it "should return data for the account" do
        result = @account.list_accounts(:searchtype => 'user', :search => 'changeme')
        result[:success].should be_true
        account = result[:params][:acct].first
        account[:email].should == "*unknown*"
        account[:shell].should == "/usr/local/cpanel/bin/noshell"
        account[:theme].should == "x3"
        account[:plan].should == "default"
        account[:suspended].should equal(false)
      end

      it "should list accounts that match a regex search for the user" do
        result = @account.list_accounts(:searchtype => 'user', :search => 'changeme')
        result[:success].should be_true
        result[:params][:acct].should have(1).account
      end

      it "should list accounts that match a regex search for the ip" do
        result = @account.list_accounts(:searchtype => 'ip', :search => '174\..*?\.166\.173')
        result[:success].should be_true
        result[:params][:acct].should have(6).accounts
      end

      it "should list accounts that match a regex search for the domain" do
        result = @account.list_accounts(:searchtype => 'domain', :search => 'ch.*?e.com')
        result[:success].should be_true
        result[:params][:acct].should have(1).account
      end
    end 

    describe "modify" do
      use_vcr_cassette "whm/account/modifyacct"

      it "should allow modifying the domain" do
        result = @account.modify(:username => 'changeme', :domain => 'example.com')
        result[:success].should be_true
        result[:params][:newcfg][:cpuser][:DOMAIN].should == 'example.com'
      end

      it "should return an error for an invalid user" do
        result = @account.modify(:username => 'notexists')
        result[:success].should_not be_true
        result[:message].should match(/Unable to fetch the cPanel user file for notexists/)
      end

      it "should return the bandwidth limit" do
        result = @account.modify(:username => 'changeme')
        result[:params][:newcfg][:cpuser][:BWLIMIT].should == "unlimited" 
      end

      it "should return the primary contact email" do
        result = @account.modify(:username => 'changeme')
        result[:params][:newcfg][:cpuser][:CONTACTEMAIL].should == "user@address.com"
      end

      it "should return the secondary contact email" do
        result = @account.modify(:username => 'changeme')
        result[:params][:newcfg][:cpuser][:CONTACTEMAIL2].should == "user2@address.com"
      end

      it "should return the main domain" do
        result = @account.modify(:username => 'changeme')
        result[:params][:newcfg][:cpuser][:DOMAIN].should == "example.com"
      end

      it "should return whether or not the domain has CGI access" do
        result = @account.modify(:username => 'changeme')
        result[:params][:newcfg][:cpuser][:HASCGI].should be_true
      end
    end 

    describe "editquota" do
      use_vcr_cassette "whm/account/editquota"

      it "should return an error for an invalid user" do
        result = @account.edit_quota(:username => 'notexists', :quota => 500)
        result[:success].should_not be_true
        result[:message].should match(/Invalid User\. Cannot set quota\./i)
      end

      it "should change the user's disk space usage quota" do
        result = @account.edit_quota(:username => 'changeme', :quota => 500)
        result[:success].should be_true
        result[:message].should match(/Set quota for user./i)
      end

      it "should fail if a negative usage quota is passed" do
        result = @account.edit_quota(:username => 'changeme', :quota => -1)
        result[:success].should_not be_true
        result[:message].should match(/Failed to set quota for user\./i)
      end
    end

    describe "summary" do
      use_vcr_cassette "whm/account/accountsummary"
      it "should require a user" do
        expect { @account.summary }.to raise_error(WhmArgumentError, /Missing required parameter: username/i)
      end

      it "should return an error for invalid users" do
        result = @account.summary(:username => 'notexists')
        result[:success].should_not be_true
        result[:message].should match(/does not exist/i)
      end

      it "should return a summary" do
        result = @account.summary(:username => 'summary')
        result[:success].should be_true
        result[:message].should match(/ok/i)
      end
    end 

    describe "suspend" do
      use_vcr_cassette "whm/account/suspend"
      it "should require a user" do
        expect { @account.suspend }.to raise_error(WhmArgumentError, /Missing required parameter: username/i)
      end

      it "should return an error for invalid users" do
        result = @account.suspend(:username => 'notexists')
        result[:success].should_not be_true
        result[:message].should match(/does not exist/i)
      end

      it "should suspend" do
        result = @account.suspend(:username => 'suspendme')
        result[:success].should be_true
        result[:message].should match(/has been suspended/i)
      end

      it "should suspend with a reason" do
        @account.server.should_receive(:perform_request).with('suspendacct', hash_including(:user => 'suspendme', :reason => 'abusive user'))

        result = @account.suspend(:username => 'suspendme', :reason => 'abusive user')
      end
    end 

    describe "unsuspend" do
      use_vcr_cassette "whm/account/unsuspend"
      it "should require a user" do
        expect { @account.unsuspend }.to raise_error(WhmArgumentError, /Missing required parameter: username/i)
      end

      it "should return an error for invalid users" do
        result = @account.unsuspend(:username => 'notexists')
        result[:success].should_not be_true
        result[:message].should match(/does not exist/i)
      end

      it "should unsuspend" do
        result = @account.unsuspend(:username => 'asdfasdf')
        result[:success].should be_true
        result[:message].should match(/unsuspending .* account/i)
      end
    end 

    describe "list_suspended" do
      use_vcr_cassette 'whm/account/listsuspended'
      it "should return non-empty result" do
        # empty isn't a real param. VCR Hacks
        result = @account.list_suspended(:empty => true)
        result[:success].should be_true
        result[:params][:accts].should_not be_empty
        result[:params][:accts].first.should include(:user => 'removeme')
      end

      it "should return empty result" do
        result = @account.list_suspended
        result[:success].should be_true
        result[:params][:accts].should be_empty
      end
    end 

    describe "change package" do
      use_vcr_cassette "whm/account/changepackage"

      it "should return an error for an invalid user" do
        result = @account.change_package(:username => 'notexists', :pkg => 'default')
        result[:success].should_not be_true
        result[:message].should match(/user notexists does not exist/i)
      end

      it "should require a user" do
        expect { @account.change_package(:pkg => '') }.to raise_error(WhmArgumentError, /Missing required parameter: username/i)
      end

      it "should require a package" do
        expect { @account.change_package(:username => 'changeme') }.to raise_error(WhmArgumentError, /Missing required parameter: pkg/i)
      end

      it "should fail if the package was not found" do
        result = @account.change_package(:username => 'changeme', :pkg => 'fakepackage')
        result[:success].should_not be_true
        result[:message].should match(/package does not exist/i)
      end

      it "should change the package" do
        result = @account.change_package(:username => 'changeme', :pkg => 'gold')
        result[:success].should be_true
        result[:message].should match(/Account Upgrade\/Downgrade Complete for changeme/i)
      end
    end 

    describe "privs" do
      use_vcr_cassette 'whm/account/myprivs'
      it "should require a user" do
        expect { @account.privs }.to raise_error(WhmArgumentError, /Missing required parameter: username/i)
      end

      it "should have a result" do
        result = @account.privs(:username => 'privs')
        result[:success].should be_true

        params = result[:params]
        expected = {:kill_dns => false, :edit_dns => false, :edit_mx => false, :add_pkg => false, 
                    :suspend_acct => false, :add_pkg_shell => false, :viewglobalpackages => false, 
                    :resftp => false, :list_accts => false, :all => true, :passwd => false, :quota => false, 
                    :park_dns => false, :rearrange_accts => false, :allow_addoncreate => false, :demo => false, 
                    :news => false, :edit_account => false, :allow_unlimited_disk_pkgs => false, :allow_parkedcreate => false, 
                    :frontpage => false, :restart => false, :ssl_gencrt => false, :allow_unlimited_pkgs => false, 
                    :add_pkg_ip => false, :disallow_shell => false, :res_cart => false, :ssl_buy => false, :kill_acct => false,
                    :allow_unlimited_bw_pkgs => false, :create_dns => false, :mailcheck => false, :clustering => false, :ssl => false,
                    :edit_pkg => false, :locale_edit => false, :show_bandwidth => false, :upgrade_account => false, :thirdparty => false,
                    :limit_bandwidth => false, :create_acct => false, :demo_setup => false, :stats => false}

        params.should include(expected)
      end
    end 

    describe "domainuserdata" do
      use_vcr_cassette "whm/account/domainuserdata"

      it "should return an error for an unknown domain" do
        result = @account.domain_user_data(:domain => 'notexists.com')
        result[:success].should_not be_true
        result[:message].should match(/Unable to determine account owner for domain\./i)
      end

      it "should require a domain" do
        expect { @account.domain_user_data() }.to raise_error(WhmArgumentError, /Missing required parameter: domain/i)
      end

      it "should return the correct data" do
        result = @account.domain_user_data(:domain => 'example.com')
        result[:success].should be_true
        result[:params][:documentroot].should == "/home/changeme/public_html"
        result[:params][:group].should == "changeme"
        result[:params][:hascgi].should_not be_true
        result[:params][:homedir].should == "/home/changeme"
        result[:params][:ip].should == "192.168.1.20"
        result[:params][:owner].should == "root"
        result[:params][:port].should == "80"
        result[:params][:scriptalias].first[:path].should == "/home/changeme/public_html/cgi-bin"
        result[:params][:scriptalias].first[:url].should == "/cgi-bin/"
        result[:params][:serveradmin].should == "webmaster@example.com"
        result[:params][:serveralias].should == "www.example.com"
        result[:params][:servername].should == "example.com"
        result[:params][:user].should == "changeme"
      end
    end 

    describe "setsiteip" do
      use_vcr_cassette "whm/account/setsiteip"

      it "should require an ip" do
        expect { @account.set_site_ip() }.to raise_error(WhmArgumentError, /Missing required parameter: ip/i)
      end

      it "should require a username or a domain" do
        expect { @account.set_site_ip(:ip => '1.1.1.1') }.to raise_error(WhmArgumentError, /may include only one of 'username, domain'/i)
      end

      it "should accept a username for the account to use" do
        result = @account.set_site_ip(:ip => '192.168.1.20', :username => 'changeme')
        result[:success].should be_true
      end

      it "should accept a domain for the account to use" do
        result = @account.set_site_ip(:ip => '192.168.1.20', :domain => 'example.com')
        result[:success].should be_true
      end

      it "should set the site ip" do
        result = @account.set_site_ip(:ip => '192.168.1.20', :username => 'changeme')
        result[:success].should be_true
        result[:message].should match(/OK/i)
      end
    end 

    describe "restore" do
      # 11.27/11.28+ only
      use_vcr_cassette "whm/account/restoreaccount"
      it "should require api.version" do
        expect { @account.restore_account(:username => 'changeme', 
                                          :type => 'monthly', 
                                          :all => false, 
                                          :ip => false, 
                                          :mail => false, 
                                          :mysql => false, 
                                          :subs => false) 
        }.to raise_error(WhmArgumentError, /Missing required parameter: api.version/i)
      end

      it "should require username" do
        expect { @account.restore_account("api.version".to_sym => 1, 
                                          :type => 'monthly', 
                                          :all => false, 
                                          :ip => false, 
                                          :mail => false, 
                                          :mysql => false, 
                                          :subs => false) 
        }.to raise_error(WhmArgumentError, /Missing required parameter: username/i)
      end

      it "should require type" do
        expect { @account.restore_account("api.version".to_sym => 1, 
                                          :username => 'changeme', 
                                          :all => false, 
                                          :ip => false, 
                                          :mail => false, 
                                          :mysql => false, 
                                          :subs => false) 
        }.to raise_error(WhmArgumentError, /Missing required parameter: type/i)
      end

      it "should require all" do
        expect { @account.restore_account("api.version".to_sym => 1, 
                                          :username => 'changeme', 
                                          :type => 'monthly', 
                                          :ip => false, 
                                          :mail => false, 
                                          :mysql => false, 
                                          :subs => false) 
        }.to raise_error(WhmArgumentError, /Missing required parameter: all/i)
      end

      it "should require ip" do
        expect { @account.restore_account("api.version".to_sym => 1, 
                                          :username => 'changeme', 
                                          :type => 'monthly', 
                                          :all => false, 
                                          :mail => false, 
                                          :mysql => false, 
                                          :subs => false) 
        }.to raise_error(WhmArgumentError, /Missing required parameter: ip/i)
      end

      it "should require mail" do
        expect { @account.restore_account("api.version".to_sym => 1, 
                                          :username => 'changeme', 
                                          :type => 'monthly', 
                                          :all => false, 
                                          :ip => false, 
                                          :mysql => false, 
                                          :subs => false) 
        }.to raise_error(WhmArgumentError, /Missing required parameter: mail/i)
      end

      it "should require mysql" do
        expect { @account.restore_account("api.version".to_sym => 1, 
                                          :username => 'changeme', 
                                          :type => 'monthly', 
                                          :all => false, 
                                          :ip => false, 
                                          :mail => false, 
                                          :subs => false) 
        }.to raise_error(WhmArgumentError, /Missing required parameter: mysql/i)
      end

      it "should require subs" do
        expect { @account.restore_account("api.version".to_sym => 1, 
                                          :username => 'changeme', 
                                          :type => 'monthly', 
                                          :all => false, 
                                          :ip => false, 
                                          :mail => false, 
                                          :mysql => false) 
        }.to raise_error(WhmArgumentError, /Missing required parameter: subs/i)
      end

      it "should return an error if it can't find the backup" do
        result = @account.restore_account("api.version".to_sym => 1, 
                                          :username => 'privs', 
                                          :type => 'daily', 
                                          :all => false, 
                                          :ip => false, 
                                          :mail => false, 
                                          :mysql => false, 
                                          :subs => false)
        result[:success].should be_false
        result[:message].should match(/Unable to find archive/i)
      end

      it "should restore the account" do
        pending "WHM API bug that returns stdout in the response headers. Waiting on ticket to be resolved" do
          result = @account.restore_account("api.version".to_sym => 1, 
                                            :username => 'changeme', 
                                            :type => 'daily', 
                                            :all => false, 
                                            :ip => false, 
                                            :mail => false, 
                                            :mysql => false, 
                                            :subs => false)
          result[:success].should be_true
          result[:message].should match(/Account Restore Complete/i)
        end
      end
    end 

    describe "verify_user" do
      use_vcr_cassette "whm/account/accountsummary"

      it "should not call the block if the user doesn't exist" do
        something = double()
        something.should_not_receive(:gold)
        expect { 
          @account.send(:verify_user, 'notexists') do
            something.gold
          end
        }.to raise_error(WhmInvalidUser)
      end

      it "should call the block if the user does exist" do
        something = double()
        something.should_receive(:gold)
        @account.send(:verify_user, 'summary') do
          something.gold
        end
      end
    end
  end
end
