# Development-only EDA: final target years are not used for feature/model decisions.
source('R/lib/modeling.R')
library(ggplot2)
p<-read_panel();d<-make_model_data(p) |> filter(year<=2021)
theme_set(theme_minimal(base_size=11))
trend<-d |> group_by(year) |> summarise(observed_states=sum(target_observed),observed_state_tons=sum(y,na.rm=TRUE))
national<-read_csv('data/clean/approved/usgs_national_context.csv',show_col_types=FALSE) |> filter(year<=2021)
trend<-left_join(trend,national,by='year',relationship='one-to-one') |>
 mutate(observed_share=observed_state_tons/national_sold_used_metric_tons)
write_table(trend,'eda_development_trend.csv')
g<-ggplot(trend,aes(year,observed_state_tons/1e6))+geom_line(linewidth=.8,color='#236b8e')+geom_point()+
 geom_line(aes(y=national_sold_used_metric_tons/1e6),linetype=2,color='#555555')+
 labs(title='Published national quantities exceed the observed-state sum',subtitle='Development years only; dashed: published national, solid: nonsuppressed state sum',x=NULL,y='Million metric tons sold or used')
ggsave('output/figures/development_trend.png',g,width=8,height=4.5,dpi=160)
state_summary<-d |> filter(target_observed) |> group_by(state) |> summarise(years=n(),mean_tons=mean(y),min_tons=min(y),max_tons=max(y),sd_log=sd(ly)) |> arrange(desc(mean_tons))
write_table(state_summary,'eda_state_summary_development.csv')
x<-filter(d,eligible_explanation)
vars<-c('ly','l_permits_t','l_highway_t','l_gdp_t')
within<-x |> group_by(state_fips) |> mutate(across(all_of(vars),~.x-mean(.x))) |> ungroup()
variation<-map_dfr(vars,function(v) {
 total_ss<-sum((x[[v]]-mean(x[[v]]))^2);within_ss<-sum(within[[v]]^2)
 tibble(variable=v,observations=nrow(x),within_share_of_total_ss=within_ss/total_ss,between_share=1-within_ss/total_ss)
})
write_table(variation,'eda_within_between.csv')
cor_tables<-map2_dfr(list(x,within),c('pooled_log','state_demeaned_log'),function(dat,label) {
 m<-cor(as.matrix(dat[vars]));as_tibble(as.table(m),.name_repair='minimal') |> setNames(c('first','second','correlation')) |> mutate(type=label)
})
write_table(cor_tables,'eda_correlations.csv')
g<-ggplot(cor_tables,aes(first,second,fill=correlation))+geom_tile()+geom_text(aes(label=sprintf('%.2f',correlation)),size=3)+
 scale_fill_gradient2(low='#c56a36',mid='white',high='#246b86',limits=c(-1,1))+
 scale_x_discrete(labels=c(ly='Quantity',l_permits_t='Permits',l_highway_t='Highway',l_gdp_t='GDP'))+
 scale_y_discrete(labels=c(ly='Quantity',l_permits_t='Permits',l_highway_t='Highway',l_gdp_t='GDP'))+
 facet_wrap(~type,labeller=as_labeller(c(pooled_log='Pooled logs',state_demeaned_log='State-demeaned logs')))+
 labs(title='Pooled relationships and within-state relationships differ',x=NULL,y=NULL)+theme(axis.text.x=element_text(angle=35,hjust=1))
ggsave('output/figures/development_correlations.png',g,width=9,height=4.5,dpi=160)
lag_relations<-d |> filter(eligible_prediction) |>
 summarise(cor_level=cor(y,lag_y),cor_growth_permits=cor(log(y/lag_y),l_permits),cor_growth_highway=cor(log(y/lag_y),l_highway),cor_growth_gdp=cor(log(y/lag_y),l_gdp))
write_table(lag_relations,'eda_lag_relationships.csv')
distribution<-map_dfr(c('y','housing_units_authorized','highway_capital_outlays_2017_million_usd','construction_gdp_chained_2017_million_usd'),function(v) {
 a<-d[[v]];a<-a[!is.na(a)];tibble(variable=v,n=length(a),minimum=min(a),median=median(a),maximum=max(a),max_to_median=max(a)/median(a),zeros=sum(a==0))
})
write_table(distribution,'eda_distributions.csv')
write_lines(c('# Provisional EDA findings - development years only','',
 'Charts and statistics use 2015-2021; no final-year performance is used to choose features.',
 paste0('Within-state target log variation accounts for ',round(100*variation$within_share_of_total_ss[variation$variable=='ly'],1),'% of total centered log-target variation in the explanatory development sample.'),
 paste0('Prior-year and current quantities have pooled correlation ',round(lag_relations$cor_level,3),'. This is descriptive evidence of persistence, not a forecast score.'),
 'State scale differences and persistent levels can inflate pooled fit. Compare original-scale errors and change prediction with the naive baseline.',
 'All primary model values are positive. Logs are feasible, with an untransformed sensitivity retained.',
 'Missingness is structured by confidentiality and source coverage. An observed-state sum is not the published national total.',
 'These are provisional descriptive observations; coefficient interpretation and model choice await Gate 2.'),'docs/eda_findings.md')
