Then /^the WhisperBack unit tests pass$/ do
  $vm.execute_successfully('/usr/lib/python3/dist-packages/whisperBack/test.py')
end
