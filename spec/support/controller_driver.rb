# frozen_string_literal: true

require "json"
require "selective-ruby-minitest"

class RecordingPipe
  def initialize(test_names)
    @test_names = test_names
  end

  def write(message)
    payload = JSON.parse(message)
    return unless payload["type"] == "test_case_result"

    data = payload["data"]
    puts "RESULT #{@test_names.fetch(data["id"])} #{data["status"]}"
  end

  def delete_pipes
  end
end

controller = Selective::Ruby::Core::Controller.new(Selective::Ruby::Minitest::RunnerWrapper, [])
runner = controller.send(:runner)
test_names = runner.test_map.to_h { |id, test| [id, "#{test[:klass].name}##{test[:method_name]}"] }
test_ids = test_names.invert

controller.instance_variable_set(:@pipe, RecordingPipe.new(test_names))
controller.define_singleton_method(:kill_transport) { |**| }

JSON.parse(ENV.fetch("DRIVER_STEPS")).each do |command, names|
  ids = Array(names).map { |name| test_ids.fetch(name) }
  case command
  when "run_test_cases"
    controller.send(:handle_command, {command: command, test_case_ids: ids})
  when "remove_failed_test_case_result"
    controller.send(:handle_command, {command: command, test_case_id: ids.first})
  when "close"
    controller.send(:handle_command, {command: command})
  end
end

abort "driver finished without a close command"
