# frozen_string_literal: true

# Build-time email split, following al-folio v1.2's al_email_protect approach
# without depending on the v1 plugin gem.
#
# When `protect_email: true`, HTML must not contain `user@host` or `mailto:`.
# Harvesters parse markup and do not run JavaScript, so a client-side rewrite
# of a plaintext address protects nobody.

module EmailProtect
  module_function

  def enabled?(site)
    site && site.config["protect_email"] == true
  end

  def split_address(value)
    address = value.to_s.strip
    return nil if address.empty?

    local, _, domain = address.rpartition("@")
    return nil if local.empty? || domain.empty?
    return nil unless domain.include?(".")

    [local, domain]
  end

  def obfuscate_text(value)
    parts = split_address(value)
    return value.to_s unless parts

    local, domain = parts
    "#{local} [at] #{domain.gsub('.', ' [dot] ')}"
  end

  module Filters
    def email_local(value)
      parts = EmailProtect.split_address(value)
      parts ? parts[0] : ""
    end

    def email_domain(value)
      parts = EmailProtect.split_address(value)
      parts ? parts[1] : ""
    end

    def email_obfuscate(value)
      return value.to_s unless EmailProtect.enabled?(@context.registers[:site])

      EmailProtect.obfuscate_text(value)
    end
  end
end

Liquid::Template.register_filter(EmailProtect::Filters)
