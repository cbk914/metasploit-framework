
module Msf
  class Evasion < Msf::Module

    include Msf::Auxiliary::Report

    class Complete < RuntimeError ; end

    class Failed < RuntimeError ; end

    def initialize(info={})
      if (info['Payload'] and info['Payload']['Compat'])
        info['Compat'] = Hash.new if (info['Compat'] == nil)
        info['Compat']['Payload'] = Hash.new if (info['Compat']['Payload'] == nil)
        info['Compat']['Payload'].update(info['Payload']['Compat'])
      end

      super(info)

      self.payload_info = info['Payload'] || {}
      self.targets = Rex::Transformer.transform(info['Targets'], Array, [ Target ], 'Targets')

      if info.key? 'DefaultTarget'
        self.default_target = info['DefaultTarget']
      else
        self.default_target = 0
        # Add an auto-target to the evasion if it doesn't have one
        if info['Targets'] && info['Targets'].count > 1 && !has_auto_target?(info['Targets'])
          # Finally, only add the target if there is a remote host option
          if self.respond_to?(:rhost) && self.respond_to?(:auto_targeted_index)
            auto = ["Automatic", {'AutoGenerated' => true}.merge(info['Targets'][self.default_target][1])]
            info['Targets'].unshift(auto)
          end
        end
      end

      if (info['Payload'] and info['Payload']['ActiveTimeout'])
        self.active_timeout = info['Payload']['ActiveTimeout'].to_i
      end

      register_options([
        OptString.new(
          'FILENAME',
            [
              true,
              'Filename for the evasive file (default: random)',
              "#{Rex::Text.rand_text_alpha(3..10)}.exe"
            ])
      ], self.class)
    end

    def self.type
      Msf::MODULE_EVASION
    end

    def type
      Msf::MODULE_EVASION
    end

    def setup
      alert_user
    end

    def file_format_filename
      datastore['FILENAME']
    end

    def file_create(data)
      fname = file_format_filename
      ltype = "evasion.fileformat.#{self.shortname}"
      full_path = store_local(ltype, nil, data, fname)
      print_good "#{fname} stored at #{full_path}"
    end

    #
    # Returns the target's platform, or the one assigned to the module itself.
    #
    def target_platform
      (target and target.platform) ? target.platform : platform
    end

    #
    # Returns the target's architecture, or the one assigned to the module
    # itself.
    #
    def target_arch
      (target and target.arch) ? target.arch : (arch == []) ? nil : arch
    end

    def normalize_platform_arch
      c_platform = (target && target.platform) ? target.platform : platform
      c_arch     = (target && target.arch)     ? target.arch     : (arch == []) ? nil : arch
      c_arch   ||= [ ARCH_X86 ]
      return c_platform, c_arch
    end

    # Returns whether the requested payload is compatible with the module
    #
    # @param [String] name The payload name
    # @param [TrueClass] Payload is compatible.
    # @param [FlaseClass] Payload is not compatible.
    def is_payload_compatible?(name)
      p = framework.payloads[name]

      pi = p.new

      # Are we compatible in terms of conventions and connections and
      # what not?
      return false if !compatible?(pi)

      # If the payload is privileged but the evasion does not give
      # privileged access, then fail it.
      return false if !self.privileged && pi.privileged

      return true
    end

    # Returns a list of compatible payloads based on platform, architecture,
    # and size requirements.
    def compatible_payloads(excluded_platforms: [], excluded_archs: [])
      payloads = []

      c_platform, c_arch = normalize_platform_arch

      # The "All" platform name represents generic payloads
      results = Msf::Modules::Metadata::Cache.instance.find(
        'type'     => [['payload'], []],
        'platform' => [[*c_platform.names, 'All'], excluded_platforms],
        'arch'     => [c_arch, excluded_archs]
      )

      results.each do |res|
        if is_payload_compatible?(res.ref_name)
          payloads << [res.ref_name, framework.payloads[res.ref_name]]
        end
      end

      payloads
    end

    def run
      raise NotImplementedError
    end

    def cleanup
    end

    def fail_with(reason, msg=nil)
      raise Msf::Evasion::Failed, "#{reason}: #{msg}"
    end

    def evasion_commands
      {}
    end

    def stance
      'passive'
    end

    def passive?
      true
    end

    def aggressive?
      false
    end

    # Generates the encoded version of the supplied payload using the payload
    # requirements specific to this evasion module. The encoded instance is returned
    # to the caller. This method is exposed in the manner that it is such that passive
    # evasions and re-generate an encoded payload on the fly rather than having to use
    # the pre-generated one.
    def generate_payload(pinst = nil)
      # Set the encoded payload to the result of the encoding process
      self.payload = generate_single_payload(pinst)

      # Save the payload instance
      self.payload_instance = (pinst) ? pinst : self.payload_instance

      return self.payload
    end

    def generate_single_payload(pinst = nil, platform = nil, arch = nil, explicit_target = nil)
      explicit_target ||= target

      # If a payload instance was supplied, use it, otherwise
      # use the active payload instance
      real_payload = (pinst) ? pinst : self.payload_instance

      if (real_payload == nil)
        raise MissingPayloadError, "No payload has been selected.",
          caller
      end

      # If this is a generic payload, then we should specify the platform
      # and architecture so that it knows how to pass things on.
      if real_payload.kind_of?(Msf::Payload::Generic)
        # Convert the architecture specified into an array.
        if arch and arch.kind_of?(String)
          arch = [ arch ]
        end

        # Define the explicit platform and architecture information only if
        # it's been specified.
        if platform
          real_payload.explicit_platform = Msf::Module::PlatformList.transform(platform)
        end

        if arch
          real_payload.explicit_arch = arch
        end

        # Force it to reset so that it will find updated information.
        real_payload.reset
      end

      # Duplicate the evasion payload requirements
      reqs = self.payload_info.dup

      # Pass save register requirements to the NOP generator
      reqs['Space']           = payload_info['Space'] ? payload_info['Space'].to_i : nil
      reqs['SaveRegisters']   = module_info['SaveRegisters']
      reqs['Prepend']         = payload_info['Prepend']
      reqs['PrependEncoder']  = payload_info['PrependEncoder']
      reqs['BadChars']        = payload_info['BadChars']
      reqs['Append']          = payload_info['Append']
      reqs['AppendEncoder']   = payload_info['AppendEncoder']
      reqs['DisableNops']     = payload_info['DisableNops']
      reqs['MaxNops']         = payload_info['MaxNops']
      reqs['MinNops']         = payload_info['MinNops']
      reqs['Encoder']         = datastore['ENCODER'] || payload_info['Encoder']
      reqs['Nop']             = datastore['NOP'] || payload_info['Nop']
      reqs['EncoderType']     = payload_info['EncoderType']
      reqs['EncoderOptions']  = payload_info['EncoderOptions']
      reqs['ExtendedOptions'] = payload_info['ExtendedOptions']
      reqs['ForceEncode']     = payload_info['ForceEncode']
      reqs['Evasion']         = self

      # Pass along the encoder don't fall through flag
      reqs['EncoderDontFallThrough'] = datastore['EncoderDontFallThrough']

      # Incorporate any context encoding requirements that are needed
      define_context_encoding_reqs(reqs)

      # Call the encode begin routine.
      encode_begin(real_payload, reqs)

      # Generate the encoded payload.
      encoded = EncodedPayload.create(real_payload, reqs)

      # Call the encode end routine which is expected to return the actual
      # encoded payload instance.
      return encode_end(real_payload, reqs, encoded)
    end

    def define_context_encoding_reqs(reqs)
      return unless datastore['EnableContextEncoding']

      # At present, we don't support any automatic methods of obtaining
      # context information.  In the future, we might support obtaining
      # temporal information remotely.

      # Pass along the information specified in our evasion datastore as
      # encoder options
      reqs['EncoderOptions'] = {} if reqs['EncoderOptions'].nil?
      reqs['EncoderOptions']['EnableContextEncoding']  = datastore['EnableContextEncoding']
      reqs['EncoderOptions']['ContextInformationFile'] = datastore['ContextInformationFile']
    end

    def encode_begin(real_payload, reqs)
    end

    def encode_end(real_payload, reqs, encoded)
      encoded
    end

    def target
      if self.respond_to?(:auto_targeted_index)
        if auto_target?
          auto_idx = auto_targeted_index
          if auto_idx.present?
            datastore['TARGET'] = auto_idx
          else
            # If our inserted Automatic Target was selected but we failed to
            # find a suitable target, we just grab the original first target.
            datastore['TARGET'] = 1
          end
        end
      end

      target_idx = target_index
      return (target_idx) ? targets[target_idx.to_i] : nil
    end

    def target_index
      target_idx =
        begin
          Integer(datastore['TARGET'])
        rescue TypeError, ArgumentError
          datastore['TARGET']
        end

      default_idx = default_target || 0
      # Use the default target if one was not supplied.
      if (target_idx == nil and default_idx and default_idx >= 0)
        target_idx = default_idx
      elsif target_idx.is_a?(String)
        target_idx = targets.index { |target| target.name == target_idx }
      end

      return (target_idx) ? target_idx.to_i : nil
    end

    def has_auto_target?(targets=[])
      target_names = targets.collect { |target| target.first}
      target_names.each do |target|
        return true if target =~ /Automatic/
      end
      return false
    end

    attr_accessor :default_target

    attr_accessor :targets

    attr_reader :payload_info

    attr_accessor :payload_info

    attr_accessor :payload_instance

    attr_accessor :payload
  end
end
