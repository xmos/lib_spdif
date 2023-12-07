def pytest_collection_modifyitems(config, items):
    selected = []
    deselected = []

    for item in items:
        m = item.get_closest_marker("uncollect_if")
        if m:
            func = m.kwargs["func"]
            if func(**item.callspec.params):
                deselected.append(item)
            else:
                selected.append(item)

    config.hook.pytest_deselected(items=deselected)
    items[:] = selected

def pytest_configure(config):
    config.addinivalue_line(
        "markers", "uncollect_if(*, func) : function to deselect tests from parametrization"
    )