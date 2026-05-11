resource "aws_dynamodb_table" "port_counter" {
  name           = "hra4you-port-counter"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "counter_id"

  attribute {
    name = "counter_id"
    type = "S"
  }

  tags = {
    Name = "hra4you-ssh-port-counter"
  }
}


resource "aws_dynamodb_table_item" "port_counter_init" {
  table_name = aws_dynamodb_table.port_counter.name
  hash_key   = "counter_id"

  item = jsonencode({
    counter_id = {
      S = "ssh_ports"
    }
    next_port = {
      N = tostring(var.base_ssh_port)
    }
  })

  lifecycle {
    ignore_changes = all
  }
}
