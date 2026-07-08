using FluentValidation;
using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.CustomerQuery.Get
{
    public class GetCustomerByIdQuery : IRequest<CustomerDto>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public class GetCustomerByIdQueryHandler : IRequestHandler<GetCustomerByIdQuery, CustomerDto?>
        {
            private readonly CustomerRepository _repository;

            public GetCustomerByIdQueryHandler(CustomerRepository repository)
            {
                _repository = repository;
            }

            public async Task<CustomerDto?> Handle(GetCustomerByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetCustomerByIdAsync(request.Id, request.CompanyId);
                return entity == null ? null : MapperCustomer.MapToCustomer(entity);
            }
        }
    }
    public class GetCustomerByIdQueryValidator : AbstractValidator<GetCustomerByIdQuery>
    {
        public GetCustomerByIdQueryValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("Customer ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
