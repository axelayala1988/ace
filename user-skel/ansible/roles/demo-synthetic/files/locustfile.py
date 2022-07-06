import os
from locust import HttpUser, task, between

def generateXDynatraceTestHeader(test_step_name):
  load_test_name = os.getenv('LOCUST_LOAD_TEST_NAME')

  x_dynatrace_test = (
    f'LSN=LocustTest;'
    f'TSN={test_step_name};'
    f'LTN={load_test_name};'
    f'VU=LocustTester;'
  )

  return x_dynatrace_test

class TestUser(HttpUser):
  wait_time = between(1, 5)

  @task
  def root(self):
    self.client.headers = {
      'x-dynatrace-test': generateXDynatraceTestHeader("Test Root"),
    }
    # self.client.get('/')
    with self.client.get("/", catch_response=True) as response:
      if response.status_code == 503:
        response.success()

  @task
  def api(self):
    self.client.headers = {
      'x-dynatrace-test': generateXDynatraceTestHeader("Test API"),
    }

    # self.client.get('/api/version')
    with self.client.get("/api/version", catch_response=True) as response:
      if response.status_code == 503:
        response.success()

    # self.client.get('/api/echo')
    with self.client.get("/api/echo", catch_response=True) as response:
      if response.status_code == 503:
        response.success()

    # self.client.get(f'/api/invoke?url={self.host}')
    with self.client.get(f'/api/invoke?url={self.host}', catch_response=True) as response:
      if response.status_code == 503:
        response.success()
