using MediatR;
using FluentValidation;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.ApplicationPropertyQuery
{
    public class GetAllApplicationPropertiesQuery : IRequest<List<ApplicationPropertyDto>>
    {
        public int CompanyId { get; set; }
        public DateTime? ModifiedAfter { get; set; }

        public class GetAllApplicationPropertiesQueryHandler : IRequestHandler<GetAllApplicationPropertiesQuery, List<ApplicationPropertyDto>>
        {
            private readonly ApplicationPropertyRepository _repository;

            public GetAllApplicationPropertiesQueryHandler(ApplicationPropertyRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ApplicationPropertyDto>> Handle(GetAllApplicationPropertiesQuery request, CancellationToken cancellationToken)
            {
                var applicationProperties = await _repository.GetAllAsync(request.CompanyId, request.ModifiedAfter);
                return applicationProperties.Select(MapperApplicationProperty.MapToApplicationPropertyDto).ToList();
            }
        }
    }

    public class GetAllApplicationPropertiesQueryValidator : AbstractValidator<GetAllApplicationPropertiesQuery>
    {
        public GetAllApplicationPropertiesQueryValidator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}