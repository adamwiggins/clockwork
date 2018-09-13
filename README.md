**This fork is no longer maintained, maybe try this one: [https://github.com/Rykian/clockwork](https://github.com/Rykian/clockwork)**

---

Clockwork - a clock process to replace cron
===========================================

Cron is non-ideal for running scheduled application tasks, especially in an app
deployed to multiple machines.  [More details.](http://adam.heroku.com/past/2010/4/13/rethinking_cron/)

Clockwork is a cron replacement.  It runs as a lightweight, long-running Ruby
process which sits alongside your web processes (Mongrel/Thin) and your worker
processes (DJ/Resque/Minion/Stalker) to schedule recurring work at particular
times or dates.  For example, refreshing feeds on an hourly basis, or send
reminder emails on a nightly basis, or generating invoices once a month on the
1st.

Quickstart
----------

Create clock.rb:

    require 'clockwork'
    include Clockwork

    handler do |job|
      puts "Running #{job}"
    end

    every(10.seconds, 'frequent.job')
    every(3.minutes, 'less.frequent.job')
    every(1.hour, 'hourly.job')

    every(1.day, 'midnight.job', :at => '00:00')

Run it with the clockwork binary:

    $ clockwork clock.rb
    Starting clock for 4 events: [ frequent.job less.frequent.job hourly.job midnight.job ]
    Triggering frequent.job

Use with queueing
-----------------

The clock process only makes sense as a place to schedule work to be done, not
to do the work.  It avoids locking by running as a single process, but this
makes it impossible to parallelize.  For doing the work, you should be using a
job queueing system, such as
[Delayed Job](http://www.therailsway.com/2009/7/22/do-it-later-with-delayed-job),
[Beanstalk/Stalker](http://adam.heroku.com/past/2010/4/24/beanstalk_a_simple_and_fast_queueing_backend/),
[RabbitMQ/Minion](http://adamblog.heroku.com/past/2009/9/28/background_jobs_with_rabbitmq_and_minion/), or
[Resque](http://github.com/blog/542-introducing-resque).  This design allows a
simple clock process with no locks, but also offers near infinite horizontal
scalability.

For example, if you're using Beanstalk/Staker:

    require 'stalker'

    handler { |job| Stalker.enqueue(job) }

    every(1.hour, 'feeds.refresh')
    every(1.day, 'reminders.send', :at => '01:30')

Using a queueing system which doesn't require that your full application be
loaded is preferable, because the clock process can keep a tiny memory
footprint.  If you're using DJ or Resque, however, you can go ahead and load
your full application environment, and use per-event blocks to call DJ or Resque
enqueue methods.  For example, with DJ/Rails:

    require 'config/boot'
    require 'config/environment'

    every(1.hour, 'feeds.refresh') { Feed.send_later(:refresh) }
    every(1.day, 'reminders.send', :at => '01:30') { Reminder.send_later(:send_reminders) }

Anatomy of a clock file
-----------------------

clock.rb is standard Ruby.  Since we include the Clockwork module (the
clockwork binary does this automatically, or you can do it explicitly), this
exposes a small DSL ("handler" and "every") to define the handler for events,
and then the events themselves.

The handler typically looks like this:

    handler { |job| enqueue_your_job(job) }

This block will be invoked every time an event is triggered, with the job name
passed in.  In most cases, you should be able to pass the job name directly
through to your queueing system.

The second part of the file are the events, which roughly resembles a crontab:

    every(5.minutes, 'thing.do')
    every(1.hour, 'otherthing.do')

In the first line of this example, an event will be triggered once every five
minutes, passing the job name 'thing.do' into the handler.  The handler shown
above would thus call enqueue_your_job('thing.do').

You can also pass a custom block to the handler, for job queueing systems that
rely on classes rather than job names (i.e. DJ and Resque).  In this case, you
need not define a general event handler, and instead provide one with each
event:

    every(5.minutes, 'thing.do') { Thing.send_later(:do) }

If you provide a custom handler for the block, the job name is used only for
logging.

You can also use blocks to do more complex checks:

    every(1.day, 'check.leap.year') do
      Stalker.enqueue('leap.year.party') if Time.now.year % 4 == 0
    end

In production
-------------

Only one clock process should ever be running across your whole application
deployment.  For example, if your app is running on three VPS machines (two app
servers and one database), your app machines might have the following process
topography:

* App server 1: 3 web (thin start), 3 workers (rake jobs:work), 1 clock (clockwork clock.rb)
* App server 2: 3 web (thin start), 3 workers (rake jobs:work)

You should use Monit, God, Upstart, or Inittab to keep your clock process
running the same way you keep your web and workers running.

Meta
----

Created by Adam Wiggins

Inspired by [rufus-scheduler](http://rufus.rubyforge.org/rufus-scheduler/) and [http://github.com/bvandenbos/resque-scheduler](resque-scehduler)

Design assistance from Peter van Hardenberg and Matthew Soldo

Patches contributed by Mark McGranaghan and Lukáš Konarovský

Released under the MIT License: http://www.opensource.org/licenses/mit-license.php

http://github.com/adamwiggins/clockwork

