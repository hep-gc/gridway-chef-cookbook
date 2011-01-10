A cookbook to run Gridway from a fresh node. It's pretty RHEL 5 centric right now. If there is anyone else in the world who wants this (kind of doubtful) patches for your distro would be accepted. :)


From a fresh install on RHEL 5:

    rpm -Uvh http://download.fedora.redhat.com/pub/epel/5/i386/epel-release-5-4.noarch.rpm
    rpm -Uvh http://download.elff.bravenet.com/5/i386/elff-release-5-3.noarch.rpm
    yum install -y chef # We use this to get chef and all its dependencies
    gem install chef ohai --source http://gems.opscode.com --source http://gems.rubyforge.org # Get a newer version that works better with SL
    chef-solo -c config/solo.rb -j config/node.json # This can take quite some time.
