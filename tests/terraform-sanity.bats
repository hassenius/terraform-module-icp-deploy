
@test "Sanity test terraform" {

  run bash -c 'cd .. ; terraform init'
  [ $status -eq 0 ]
}
