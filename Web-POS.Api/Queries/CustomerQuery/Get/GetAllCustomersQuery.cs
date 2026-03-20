using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.CustomerQuery.Get
{
    public class GetAllCustomersQuery : IRequest<List<CustomerDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllCustomersQueryHandler : IRequestHandler<GetAllCustomersQuery, List<CustomerDto>>
        {
            private readonly CustomerRepository _customerRepository ;
            public GetAllCustomersQueryHandler(CustomerRepository customerRepository)
            {
                _customerRepository = customerRepository;
            }

            public async Task<List<CustomerDto>> Handle(GetAllCustomersQuery request, CancellationToken cancellationToken)
            {
                var customers = await _customerRepository.GetAllCustomers(request.CompanyId);
                return customers.Select(MapperCustomer.MapToCustomer).ToList();
            }
        }
    }
    public class GetAllCustomersQueryValidator : AbstractValidator<GetAllCustomersQuery>
    {
        public GetAllCustomersQueryValidator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
