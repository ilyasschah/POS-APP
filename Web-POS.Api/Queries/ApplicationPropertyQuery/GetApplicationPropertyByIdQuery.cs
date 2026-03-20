using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
using MediatR;
using FluentValidation;

namespace Products.Api.Queries.ApplicationPropertyQuery
{
    public class GetApplicationPropertyByIdQuery : IRequest<ApplicationPropertyDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
    }

    public class GetApplicationPropertyByIdQueryHandler : IRequestHandler<GetApplicationPropertyByIdQuery, ApplicationPropertyDto?>
    {
        private readonly ApplicationPropertyRepository _repository;

        public GetApplicationPropertyByIdQueryHandler(ApplicationPropertyRepository repository)
        {
            _repository = repository;
        }

        public async Task<ApplicationPropertyDto?> Handle(GetApplicationPropertyByIdQuery request, CancellationToken cancellationToken)
        {
            var entity = await _repository.GetByIdAsync(request.Id, request.CompanyId);
            return entity == null ? null : MapperApplicationProperty.MapToApplicationPropertyDto(entity);
        }
    }

    public class GetApplicationPropertyByIdQueryValidator : AbstractValidator<GetApplicationPropertyByIdQuery>
    {
        public GetApplicationPropertyByIdQueryValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}