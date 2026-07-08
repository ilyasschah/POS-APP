using MediatR;
using FluentValidation;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.ApplicationPropertyQuery
{
    public class GetApplicationPropertyByNameQuery : IRequest<ApplicationPropertyDto?>
    {
        public string Name { get; set; }
        public int CompanyId { get; set; }
    }

    public class GetApplicationPropertyByNameQueryHandler : IRequestHandler<GetApplicationPropertyByNameQuery, ApplicationPropertyDto?>
    {
        private readonly ApplicationPropertyRepository _repository;

        public GetApplicationPropertyByNameQueryHandler(ApplicationPropertyRepository repository)
        {
            _repository = repository;
        }

        public async Task<ApplicationPropertyDto?> Handle(GetApplicationPropertyByNameQuery request, CancellationToken cancellationToken)
        {
            var entity = await _repository.GetByNameAsync(request.Name, request.CompanyId);
            return entity == null ? null : MapperApplicationProperty.MapToApplicationPropertyDto(entity);
        }
    }

    public class GetApplicationPropertyByNameQueryValidator : AbstractValidator<GetApplicationPropertyByNameQuery>
    {
        public GetApplicationPropertyByNameQueryValidator()
        {
            RuleFor(x => x.Name).NotEmpty().WithMessage("Name is required.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}