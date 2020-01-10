testo:
  test.nop:
    - name: {{ pillar.get('hello') }}
    - hello: world
