#!/nix/store/xkvjcsv75k1z7yjdwglz423wfl8biv0p-python3-3.7.9/bin/python
"""Django's command-line utility for administrative tasks."""
import os
import sys


def main():
  os.environ.setdefault("DJANGO_SETTINGS_MODULE", "bella.settings")
  try:
    from django.core.management import execute_from_command_line
  except ImportError as exc:
    raise ImportError(
      "Couldn't import Django. Are you sure it's installed and "
      "available on your PYTHONPATH environment variable? Did you "
      "forget to activate a virtual environment?"
    ) from exc
  execute_from_command_line(sys.argv)


if __name__ == "__main__":
  main()
