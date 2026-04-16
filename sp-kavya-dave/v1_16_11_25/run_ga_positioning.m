function [best_position, best_fitness, fitness_history, results] = ...
         run_ga_positioning(config, ga_params)
    % Main GA function for AP positioning optimization
    
    population = initialize_population(ga_params.population_size, ...
                                     config.num_sensors, config.search_area);
    
    fitness_history = zeros(ga_params.num_generations, 1);
    best_fitness = inf;
    best_position = [];
    
    for generation = 1:ga_params.num_generations
        fitness = zeros(ga_params.population_size, 1);
        for i = 1:ga_params.population_size
            fitness(i) = evaluate_fitness(population(i, :), config);
        end
        
        [current_best_fitness, best_idx] = min(fitness);
        if current_best_fitness < best_fitness
            best_fitness = current_best_fitness;
            best_position = population(best_idx, :);
        end
        fitness_history(generation) = best_fitness;
        
        if mod(generation, 10) == 0
            fprintf('Generation %d: Best Fitness = %.4f\n', generation, best_fitness);
        end
        
        population = evolve_population(population, fitness, ga_params, config);
    end
    
    results = struct();
    results.config = config;
    results.ga_params = ga_params;
end

function fitness = evaluate_fitness(individual, config)
    sensors = reshape(individual, 2, config.num_sensors)';
    all_references = sensors; % APs act as references
    
    total_error = 0;
    for t = 1:size(config.targets, 1)
        target = config.targets(t, :);
        distances = sqrt(sum((all_references - target).^2, 2));
        
        noisy_distances = distances + config.noise_std * randn(size(distances));
        noisy_distances = max(noisy_distances, 0.1);
        
        estimated_pos = trilateration(all_references, noisy_distances);
        error = norm(estimated_pos - target);
        total_error = total_error + error;
    end
    
    % Penalty for APs too close together
    penalty = 0;
    min_separation = 5;
    for i = 1:config.num_sensors
        for j = i+1:config.num_sensors
            dist = norm(sensors(i, :) - sensors(j, :));
            if dist < min_separation
                penalty = penalty + (min_separation - dist)^2;
            end
        end
    end
    
    fitness = total_error + 0.1 * penalty;
end

function new_population = evolve_population(population, fitness, ga_params, config)
    pop_size = size(population, 1);
    new_population = zeros(size(population));
    
    [~, sorted_idx] = sort(fitness);
    for i = 1:ga_params.elite_size
        new_population(i, :) = population(sorted_idx(i), :);
    end
    
    for i = (ga_params.elite_size + 1):pop_size
        parent1 = tournament_selection(population, fitness, ga_params.tournament_size);
        parent2 = tournament_selection(population, fitness, ga_params.tournament_size);
        
        if rand() < ga_params.crossover_rate
            child = crossover(parent1, parent2);
        else
            child = parent1;
        end
        
        child = mutate(child, ga_params.mutation_rate, config.search_area);
        new_population(i, :) = child;
    end
end

function population = initialize_population(pop_size, num_sensors, search_area)
    chromosome_length = num_sensors * 2;
    population = zeros(pop_size, chromosome_length);
    
    for i = 1:pop_size
        for j = 1:2:chromosome_length
            population(i, j) = rand() * (search_area(1, 2) - search_area(1, 1)) + search_area(1, 1);
            population(i, j+1) = rand() * (search_area(2, 2) - search_area(2, 1)) + search_area(2, 1);
        end
    end
end

function estimated_pos = trilateration(references, distances)
    if size(references, 1) < 3
        estimated_pos = mean(references, 1);
        return;
    end
    
    try
        A = [];
        b = [];
        
        for i = 2:min(size(references, 1), 6)
            A = [A; 2*(references(i, 1) - references(1, 1)), ...
                     2*(references(i, 2) - references(1, 2))];
            b = [b; distances(i)^2 - distances(1)^2 - ...
                    references(i, 1)^2 + references(1, 1)^2 - ...
                    references(i, 2)^2 + references(1, 2)^2];
        end
        
        if size(A, 1) >= 2 && rank(A) == 2
            estimated_pos = (A'*A)\(A'*b);
            estimated_pos = estimated_pos';
        else
            estimated_pos = mean(references, 1);
        end
    catch
        estimated_pos = mean(references, 1);
    end
end

function selected = tournament_selection(population, fitness, tournament_size)
    pop_size = size(population, 1);
    tournament_idx = randperm(pop_size, tournament_size);
    tournament_fitness = fitness(tournament_idx);
    [~, winner_idx] = min(tournament_fitness);
    selected = population(tournament_idx(winner_idx), :);
end

function child = crossover(parent1, parent2)
    chromosome_length = length(parent1);
    crossover_point = randi([1, chromosome_length-1]);
    child = [parent1(1:crossover_point), parent2(crossover_point+1:end)];
end

function mutated = mutate(individual, mutation_rate, search_area)
    mutated = individual;
    
    for i = 1:length(individual)
        if rand() < mutation_rate
            if mod(i, 2) == 1 % x coordinate (Latitude)
                mutation = randn() * 2;
                mutated(i) = mutated(i) + mutation;
                mutated(i) = max(search_area(1, 1), min(search_area(1, 2), mutated(i)));
            else % y coordinate (Longitude)
                mutation = randn() * 2;
                mutated(i) = mutated(i) + mutation;
                mutated(i) = max(search_area(2, 1), min(search_area(2, 2), mutated(i)));
            end
        end
    end
end