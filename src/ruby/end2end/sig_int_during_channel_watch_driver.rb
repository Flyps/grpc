#!/usr/bin/env ruby

# Copyright 2016 gRPC authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# abruptly end a process that has active calls to
# Channel.watch_connectivity_state

require_relative './end2end_common'

def main
  STDERR.puts 'start server'
  server_runner = ServerRunner.new(EchoServerImpl)
  server_port = server_runner.run

  sleep 1

  STDERR.puts 'start client'
  _, client_pid = start_client('sig_int_during_channel_watch_client.rb',
                               server_port)

  # give time for the client to get into the middle
  # of a channel state watch call
  sleep 1
  Process.kill('SIGINT', client_pid)

  begin
    Timeout.timeout(10) do
      Process.wait(client_pid)
    end
  rescue Timeout::Error
    STDERR.puts "timeout wait for client pid #{client_pid}"
    Process.kill('SIGKILL', client_pid)
    Process.wait(client_pid)
    STDERR.puts 'killed client child'
    raise 'Timed out waiting for client process. It likely hangs when a ' \
      'SIGINT is sent while there is an active connectivity_state call'
  end

  client_exit_code = $CHILD_STATUS
  if client_exit_code != 0
    fail "sig_int_during_channel_watch_client failed: #{client_exit_code}"
  end

  server_runner.stop
end

main
