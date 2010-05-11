Clockwork - a scheduler process to replace cron
===============================================

Cron is non-ideal for running scheduled application tasks, especially in an app
deployed to multiple machines.  [More details.](http://adam.heroku.com/past/2010/4/13/rethinking_cron/)

Clockwork is a lightweight, long-running Ruby process which sits alongside your
web processes (Mongrel/Thin) and your worker processes (DJ/Resque/Minion/Stalker)
to schedule recurring work at particular times or dates.  For example,
refreshing feeds on an hourly basis, or send reminder emails on a nightly
basis, or generating invoices once a month on the 1st.

Example
-------

Create schedule.rb:

    require 'clockwork'
    include Clockwork

    every('10s') { puts 'every 10 seconds' }
    every( '3m') { puts 'every 3 minutes' }
    every( '1h') { puts 'once an hour' }

    every('1d', :at => '00:00') { puts 'every night at midnight' }

Run it with the clockwork binary:

    $ clockwork schedule.rb

Or run directly with Ruby:

    $ ruby -r schedule -e Clockwork.run

Use with queueing
-----------------

Clockwork only makes sense as a place to schedule work to be done, not to do
the work.  It avoids locking by running as a single process, but this makes it
impossible to parallelize.  For doing the work, you should be using a job
queueing system, such as
[Delayed Job](http://www.therailsway.com/2009/7/22/do-it-later-with-delayed-job),
[Beanstalk/Stalker](http://adam.heroku.com/past/2010/4/24/beanstalk_a_simple_and_fast_queueing_backend/),
[RabbitMQ/Minion](http://adamblog.heroku.com/past/2009/9/28/background_jobs_with_rabbitmq_and_minion/), or
[Resque](http://github.com/blog/542-introducing-resque).  This design allows
a simple scheduler process with no locks, but also offers near infinite
horizontal scalability.

For example, if you're using Beanstalk/Staker:

    require 'clockwork'
    include Clockwork

    require 'stalker'
    include Stalker

    every('1h') { enqueue('feeds.refresh') }
    every('1d', :at => '01:30') { enqueue('reminders.send') }

Using a queueing system which doesn't require that your full application be
loaded is preferable, because the scheduler process can keep a tiny memory
footprint.  If you're using DJ or Resque, however, you can go ahead and load
your full application enviroment.  For example, with DJ/Rails:

    require 'config/boot'
    require 'config/environment'

    require 'clockwork'
    include Clockwork

    every('1h') { Feed.send_later(:refresh) }
    every('1d', :at => '01:30') { Reminder.send_later(:send_reminders) }

In production
-------------

Only one scheduler process should ever be running across your whole application
deployment.  For example, if your app is running on three VPS machines (two app
servers and one database), your app machines might have the following process
topography:

* Machine 1: 3 web (thin start), 3 workers (rake jobs:work), 1 scheduler (clockwork schedule.rb)
* Machine 2: 3 web (thin start), 3 workers (rake jobs:work)

You should use Monit, God, Upstart, or Inittab to keep your scheduler process
running the same way you keep your web and workers running.

Meta
----

Created by Adam Wiggins

Inspired by [rufus-scheduler](http://rufus.rubyforge.org/rufus-scheduler/) and [http://github.com/bvandenbos/resque-scheduler](resque-scehduler)

Released under the MIT License: http://www.opensource.org/licenses/mit-license.php

http://github.com/adamwiggins/clockwork

