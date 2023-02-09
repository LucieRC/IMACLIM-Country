// Est exécuté ligne 377 d'ImaclimS.sce :
// if Optimization_Resol then
//     if part(SystemOpt_Resol,1:length(OptHomo_Shortname))<> OptHomo_Shortname
//         exec(STUDY_Country+study+".sce");


//////////////////////////////////////////////// OLD - A SUPPRIMER ?  /////////////////////////////////////////////////////////////////////////////////////

// update carbon tax rate
// parameters.Carbon_Tax_rate = 110000;

// Basic Need  in ktep/UC
BasicNeed = zeros(nb_Sectors,1);
// Put in sectoral parameters 
BasicNeed_HH = (BasicNeed .*.ones(1,nb_Households));

// Data for Households are in thousand of people
Coef_HH_unitpeople = 10^3;

// sensitivity analysis 
parameters.sigma_X = parameters.sigma_X * (1+strtod(Trade_elast_var));
parameters.sigma_M = parameters.sigma_M * (1+strtod(Trade_elast_var));

//////////////////////////////////////////////// WAGE CURVE  /////////////////////////////////////////////////////////////////////////////////////


//////////////////////////////////////////////// GESTION DES KAPPAS  /////////////////////////////////////////////////////////////////////////////////////


//////////////////////////////////////////////// CONTROLE DES PRIX DE L'ENERGIE  /////////////////////////////////////////////////////////////////////////////////////

// On fait varier les coefficients techniques de liquid_fuels et de gas_fuels dans l'AMS,
// pour obtenir en sortie des écarts de prix par rapport à l'AME similaires à ceux des données de la DGEC
if Scenario=='AMS2035' & energy_prices_controlled=='True' then

    // Get the initial value of the alphas for liquid_fuels and gas_fuels
    alpha_init = Proj_Vol('alpha').val;
    alpha_liquid_init = alpha_init(1:5, Indice_OilS);
    alpha_gas_init = alpha_init(1:5, Indice_GasS);
    
    // Calculate the new values of the alphas, depending on time_step
    // VALEURS DE MULTIPLICATEURS JUSQU'AU 8 FEVRIER 17H
    // if time_step == 1
    //     alpha_liquid_new = alpha_liquid_init * 0.95;
    //     alpha_gas_new = alpha_gas_init * 2.30;
	// elseif time_step == 2
    //     alpha_liquid_new = alpha_liquid_init * 0.95;
    //     alpha_gas_new = alpha_gas_init * 2.30;
    // elseif time_step == 3
    //     alpha_liquid_new = alpha_liquid_init * 0.67;
    //     alpha_gas_new = alpha_gas_init * 1.53;
    // elseif time_step == 4
    //     alpha_liquid_new = alpha_liquid_init * 0.24;
    //     alpha_gas_new = alpha_gas_init * 1.52;
	// end

    // VALEURS DE MULTIPLICATEURS APRES LE 8 FEVRIER 17H
    if time_step == 1
        alpha_liquid_new = alpha_liquid_init * 0.95;
        alpha_gas_new = alpha_gas_init * 2.30;
	elseif time_step == 2
        alpha_liquid_new = alpha_liquid_init * 0.95;
        alpha_gas_new = alpha_gas_init * 2.30;
    elseif time_step == 3
        alpha_liquid_new = alpha_liquid_init * 0.67;
        alpha_gas_new = alpha_gas_init * 1.53;
    elseif time_step == 4
        alpha_liquid_new = alpha_liquid_init * 0.24;
        alpha_gas_new = alpha_gas_init * 1.52;
	end


    // Force the new values of the alphas for liquid_fuels and gas_fuels
    alpha_new = alpha_init;
    alpha_new(1:5, Indice_OilS) = alpha_liquid_new;
    alpha_new(1:5, Indice_GasS) = alpha_gas_new;
    //Deriv_Exogenous.alpha = alpha_new;
    Proj_Vol('alpha').val = alpha_new;
    
    // After the resolution, there is a test on wether the projection went well or not,
    // line 442 of ImaclimS.sce, calling Check_Proj_Vol.sce".
    // We put the new values of alpha in Proj_Vol to succeed this test.
    //Proj_Vol('alpha').val = alpha_new;
end


//////////////////////////////////////////////// CONTROLE DE LA TICGN (TICPE pour le gaz) /////////////////////////////////////////////////////////////////////////////////////

if Scenario=='AMS2035' & ticgn_controlled=='True' then

    // Get the initial value of the TICGN rate
    BY_ticgn_rate = BY.Energy_Tax_rate_IC(1,Indice_GasS);

    // Calculate the new value of the TICGN rate, depending on time_step
    if time_step == 1
        new_ticgn_rate = BY_ticgn_rate * 2.61; // Multiplier's values come from "Prix - AME2021_V 17 - avec calculs.xlsx"
	elseif time_step == 2
        new_ticgn_rate = BY_ticgn_rate * 3.84;
    elseif time_step == 3
        new_ticgn_rate = BY_ticgn_rate * 3.42;
    elseif time_step == 4
        new_ticgn_rate = BY_ticgn_rate * 2.29;
	end

    // Force the new value of TICGN rate
    Deriv_Exogenous.Energy_Tax_rate_IC = Energy_Tax_rate_IC;
    Deriv_Exogenous.Energy_Tax_rate_IC(1,Indice_GasS) = new_ticgn_rate;

end

//////////////////////////////////////////////// EMISSIONS  /////////////////////////////////////////////////////////////////////////////////////

// On réduit les facteurs d'émissions selon la proportion de bioénergie utilisée
// --> doute si utiliser d.Emission_Coef_IC ou juste Emission_Coef_IC 
if emissions_bioenergy == 'True' & 0 then
    Deriv_Exogenous.Emission_Coef_IC = Emission_Coef_IC;

	bioenergy_proportions_filename = 'bioenergy_proportions_' + Scenario; // Creation of a string like "bioenergy_proportions_AME"
	bioenergy_proportions = evstr(bioenergy_proportions_filename); // Get the value of the var named bioenergy_proportions_AME
	bioenergy_proportions = repmat(bioenergy_proportions(:,time_step)', nb_Sectors, 1)'; // Reproduction of the column corresponding to time_step
	Deriv_Exogenous.Emission_Coef_IC(Indice_EnerSect, :) = Emission_Coef_IC(Indice_EnerSect, :) .* (ones(5 , nb_Sectors) - bioenergy_proportions); // Reducing the emissions factors by the proportions of bioenergy
end

//////////////////////////////////////////////// ACTIFS ECHOUES  /////////////////////////////////////////////////////////////////////////////////////


//////////////////////////////////////////////// CONTROLE pY GAZ PAR RAPPORT A pM GAZ  /////////////////////////////////////////////////////////////////////////////////////
// pY(gaz) valait 40 fois pM(gaz) en 2050, donnant une facture de gaz de 100 milliards dans l'AMS !
// Le ratio Labour_income / Yq est 50 fois supérieur pour le gaz_fuel que pour le liquid_fuel. Alors on divise la plupart des variables
// de gaz_fuels par 50

if pY_ini_gaz_controlled == 'True' then
    disp(time_step)
    if time_step == 1 then
        diviseur = 1000;

        //disp(alpha(1:nb_Sectors, Indice_GasS))
        
        Deriv_Exogenous.alpha = alpha;
        Deriv_Exogenous.alpha(1:nb_Sectors,Indice_GasS) = alpha(1:nb_Sectors, Indice_GasS) ./ diviseur;

        // We put the new value of alpha in Proj_Vol, to pass the test on wether the projection went well or not
        Proj_Vol('alpha').val = Deriv_Exogenous.alpha;
        disp('toto')
        disp(lambda(Indice_GasS))
        
        Deriv_Exogenous.lambda = lambda;
        Deriv_Exogenous.lambda(Indice_GasS) = lambda(Indice_GasS) / diviseur;
        
        disp(kappa(Indice_GasS))

        Deriv_Exogenous.kappa = kappa;
        Deriv_Exogenous.kappa(Indice_GasS) = kappa(Indice_GasS) / diviseur;
        
        // Changing the Profit_margin gives an unbalanced IOT
        //Deriv_Exogenous.Profit_margin = Profit_margin;
        //Deriv_Exogenous.Profit_margin(Indice_GasS) = Profit_margin(Indice_GasS) / diviseur;
    else
        disp(alpha(1:nb_Sectors, Indice_GasS))
        disp(lambda(Indice_GasS))
        disp(kappa(Indice_GasS))
        
        Deriv_Exogenous.alpha = alpha;
        Proj_Vol('alpha').val = alpha;
        Deriv_Exogenous.lambda = lambda;
        Deriv_Exogenous.kappa = kappa;
    end

end

