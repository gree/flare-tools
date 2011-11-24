# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

module Flare
  module Util
    module Interruption
      @@__interrupts__ = []

      def self.included(klass)
        ObjectSpace.each_object(klass) {|inst|
          inst.initialize_rands
        }
        
        klass.class_eval {
          alias_method :initialize_before_interruption, :initialize
          def initialize(*args)
            initialize_before_interruption(*args)
            initialize_interruption
          end
        }
      end

      def self.interrupt_all
        puts @@__interrupts__
        @@__interrupts__.each do |x|
          x.interrupt
        end
      end

      def initialize_interruption
        @@__interrupts__ << self
        @__interruptible__ = false
        @__interrupted__ = false
      end

      def interruptible(&block)
        @__interruptible__ = true
        block.call
      ensure
        @__interruptible__ = false
      end

      def interruptible?
        @__interruptible__
      end
      
      def interrupted?
        @__interrupted__
      ensure
        @__interrupted__ = false
      end
      
      def interrupt
        @__interrupted__ = true
        if interruptible?
          info "INTERRUPTED"
          exit 1 
        end
      end

    end
  end
end

Signal.trap(:INT) do
  print "^C"
  Flare::Util::Interruption.interrupt_all
end

