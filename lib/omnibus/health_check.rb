module Omnibus
  class HealthCheck

    WHITELIST_LIBS = [/linux-vdso.+/,
                      /libc\.so/,
                      /ld-linux/,
                      /libdl/,
                      /libpthread/,
                      /libm\.so/,
                      /libcrypt\.so/,
                      /librt\.so/,
                      /libutil\.so/,
                      /libgcc_s\.so/,
                      /libstdc\+\+\.so/,
                      /libnsl\.so/,
                      /libfreebl\d\.so/,
                      /libresolv\.so/,
                      /libaio\.so/,     # solaris
                      /libavl\.so/,     # solaris
                      /libdoor\.so/,    # solaris
                      /libgen\.so/,     # solaris
                      /libmd\.so/,      # solaris
                      /libmp\.so/,      # solaris
                      /libscf\.so/,     # solaris
                      /libsec\.so/,     # solaris
                      /libsocket\.so/,  # solaris
                      /libuutil\.so/,   # solaris
                      /libcrypt_d\.so/] # solaris

    def self.run(install_dir)
      ldd_cmd = "find #{install_dir} -type f | xargs ldd"
      shell = Mixlib::ShellOut.new(ldd_cmd)
      shell.run_command

      ldd_output = shell.stdout

      bad_libs = {}

      current_library = nil 
      ldd_output.split("\n").each do |line|
        case line
        when /^(.+):$/
          current_library = $1
        when /^\s+(.+) \=\>\s+(.+)( \(.+\))?$/
          name = $1
          linked = $2
          safe = nil
          WHITELIST_LIBS.each do |reg| 
            safe ||= true if reg.match(name)
          end
          safe ||= true if current_library =~ /jre\/lib/

          if !safe && linked !~ Regexp.new(install_dir)
            bad_libs[current_library] ||= {}
            bad_libs[current_library][name] ||= {} 
            if bad_libs[current_library][name].has_key?(linked)
              bad_libs[current_library][name][linked] += 1 
            else
              bad_libs[current_library][name][linked] = 1 
            end
          else
            puts "Passed: #{current_library} #{name} #{linked}" if ARGV[0] == 'verbose'
          end
        when /^\s+(.+) \(.+\)$/
          next
        when /^\s+statically linked$/
          next
        when /^\s+libjvm.so/
          next
        when /^\s+libjava.so/
          next
        when /^\s+libmawt.so/
          next
        when /^\s+not a dynamic executable$/ # ignore non-executable files
        else
          puts "line did not match for #{current_library}\n#{line}"
        end
      end

      if bad_libs.keys.length > 0
        bad_libs.each do |name, lib_hash|
          lib_hash.each do |lib, linked_libs|
            linked_libs.each do |linked, count|
              puts "#{name}: #{lib} #{linked} #{count}"
            end
          end
        end
        raise "Health Check Failed"
      end
    end

  end
end
