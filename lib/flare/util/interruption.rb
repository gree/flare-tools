# -*- coding: utf-8; -*-
# Authors::   Kiyoshi Ikehara <kiyoshi.ikehara@gree.co.jp>
# Copyright:: Copyright (C) Gree,Inc. 2011. All Rights Reserved.
# License::   NOTYET

module Flare
  module Util
    module Interruption
      InterruptionTargets = []

      def self.included(klass)
        klass.class_eval {
          alias_method :initialize_before_interruption, :initialize
          def initialize(*args)
            super
            initialize_before_interruption(*args)
            initialize_interruption
          end
        }
      end

      def self.interrupt_all
        InterruptionTargets.each do |x|
          x.interrupt_
        end
      end

      def initialize_interruption
        InterruptionTargets.push self
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

      def interrupt_
        @__interrupted__ = true
        interrupt
      end
      
      def interrupt
        if interruptible?
          info "INTERRUPTED"
          exit 1 
        end
      end

    end
  end
end

Signal.trap(:INT) do
  Flare::Util::Interruption.interrupt_all
end

