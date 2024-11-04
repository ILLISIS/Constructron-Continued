

-- for each job get worker logistic sections and set filter to {}
for _, job in pairs(storage.jobs) do
    -- change quality of each required item to "normal"
    for _, value in pairs(job.required_items) do
        for quality, count in pairs(value) do
            if quality == "quality-unknown" then
                value["normal"] = count
                value[quality] = nil
            end
        end
    end
    local logistic_point = job.worker.get_logistic_point(0)
    if logistic_point then
        local section = logistic_point.get_section(1)
        if section then
            for slot, filter in pairs(section.filters) do
                if filter.value then
                    if filter.value.quality == "quality-unknown" then
                        section.set_slot(slot, {
                            value = {
                                name = filter.value.name,
                                quality = "normal",
                            },
                            min = filter.value.min,
                            max = filter.value.max
                        })
                    end
                end
            end
        end
    end
end
